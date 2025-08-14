//
//  UnplannedExpenseService.swift
//  SoFar
//
//  Purpose:
//  - CRUD for UnplannedExpense entities
//  - Fetch helpers (by card, by category, by date range, by budget via Card→Budget link)
//  - Totals helpers (by card, by budget within a date interval)
//  - Calendar-friendly helpers: fetch by range/month, group by day, expand simple recurrences
//  - Parent/child utilities for splitting/linking expenses
//
//  Model expectations (based on your notes/snapshot):
//    UnplannedExpense:
//      id: UUID
//      descriptionText: String     // (We also tolerate a "title" drift; see helpers.)
//      amount: Double
//      transactionDate: Date
//      recurrence: String?         // "weekly","biweekly","monthly","semimonthly", etc.
//      recurrenceEndDate: Date?
//      secondBiMonthlyDate: Date?  // NOTE: Some snapshots use Int16 day-of-month instead.
//                                  // We support both Date("secondBiMonthlyDate") and Int16("secondBiMonthlyDay"/"secondPayDay").
//      parentID: UUID?             // optional
//      Relationships:
//        card: Card (to-one)
//        expenseCategory: ExpenseCategory (to-one)
//        parentExpense: UnplannedExpense (to-one)
//        childExpense: UnplannedExpense (to-many)
//    Card ↔ Budget: many-to-many (Card.budget <-> Budget.cards)
//
//  Conventions:
//  - We never access `.id` directly (KVC only) to avoid Identifiable ambiguity.
//  - Predicates use literal "id" / "card.id" / "expenseCategory.id" / "ANY card.budget.id".
//  - Relationship sets are done via KVC to be codegen-agnostic.
//  - Recurrence expansion mirrors IncomeService logic for UI display only (does not persist).
//

import Foundation
import CoreData

// MARK: - UnplannedExpenseService
final class UnplannedExpenseService {
    
    // MARK: Types
    
    /// Calendar-friendly, read-only projection for UI (e.g., dots on a calendar).
    struct UnplannedEvent: Hashable {
        let objectID: NSManagedObjectID?
        let date: Date
        let title: String
        let amount: Double
        let isProjected: Bool   // true if from recurrence expansion (not persisted)
    }
    
    // MARK: Properties
    private let expenseRepo: CoreDataRepository<UnplannedExpense>
    private let cardRepo: CoreDataRepository<Card>
    private let categoryRepo: CoreDataRepository<ExpenseCategory>
    private let budgetRepo: CoreDataRepository<Budget>
    private let calendar: Calendar
    
    // MARK: Init
    /// - Parameters:
    ///   - stack: Core Data stack (defaults to CoreDataService.shared).
    ///   - calendar: Calendar used for date math (defaults to current).
    init(stack: CoreDataStackProviding = CoreDataService.shared,
         calendar: Calendar = .current) {
        self.expenseRepo = CoreDataRepository<UnplannedExpense>(stack: stack)
        self.cardRepo = CoreDataRepository<Card>(stack: stack)
        self.categoryRepo = CoreDataRepository<ExpenseCategory>(stack: stack)
        self.budgetRepo = CoreDataRepository<Budget>(stack: stack)
        self.calendar = calendar
    }
    
    // MARK: - FETCH
    
    // MARK: fetchAll(sortedByDateAscending:)
    /// Fetch all unplanned expenses.
    func fetchAll(sortedByDateAscending: Bool = true) throws -> [UnplannedExpense] {
        let sort = NSSortDescriptor(key: "transactionDate", ascending: sortedByDateAscending)
        return try expenseRepo.fetchAll(sortDescriptors: [sort])
    }
    
    // MARK: find(byID:)
    /// Find a single expense by UUID.
    func find(byID id: UUID) throws -> UnplannedExpense? {
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try expenseRepo.fetchFirst(predicate: predicate)
    }
    
    // MARK: fetchForCard(_:in:sortedByDateAscending:)
    /// Fetch expenses for a given card, optionally constrained to a date interval.
    func fetchForCard(_ cardID: UUID,
                      in interval: DateInterval? = nil,
                      sortedByDateAscending: Bool = true) throws -> [UnplannedExpense] {
        var predicate: NSPredicate
        if let interval {
            predicate = NSPredicate(format: "card.id == %@ AND transactionDate >= %@ AND transactionDate <= %@",
                                    cardID as CVarArg, interval.start as CVarArg, interval.end as CVarArg)
        } else {
            predicate = NSPredicate(format: "card.id == %@", cardID as CVarArg)
        }
        let sort = NSSortDescriptor(key: "transactionDate", ascending: sortedByDateAscending)
        return try expenseRepo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: fetchForCategory(_:in:sortedByDateAscending:)
    /// Fetch expenses for a given category, optionally constrained to a date interval.
    func fetchForCategory(_ categoryID: UUID,
                          in interval: DateInterval? = nil,
                          sortedByDateAscending: Bool = true) throws -> [UnplannedExpense] {
        var predicate: NSPredicate
        if let interval {
            predicate = NSPredicate(format: "expenseCategory.id == %@ AND transactionDate >= %@ AND transactionDate <= %@",
                                    categoryID as CVarArg, interval.start as CVarArg, interval.end as CVarArg)
        } else {
            predicate = NSPredicate(format: "expenseCategory.id == %@", categoryID as CVarArg)
        }
        let sort = NSSortDescriptor(key: "transactionDate", ascending: sortedByDateAscending)
        return try expenseRepo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: fetchForBudget(_:in:sortedByDateAscending:)
    /// Fetch unplanned expenses that should be considered for a budget,
    /// by linking via Card↔Budget and constraining to the date interval.
    /// - Important: This respects the current model (no direct Budget link on UnplannedExpense).
    func fetchForBudget(_ budgetID: UUID,
                        in interval: DateInterval,
                        sortedByDateAscending: Bool = true) throws -> [UnplannedExpense] {
        // ANY card.budget.id == budgetID (Card is to-one, Card.budget is to-many)
        let predicate = NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@ AND ANY card.budget.id == %@",
                                    interval.start as CVarArg, interval.end as CVarArg, budgetID as CVarArg)
        let sort = NSSortDescriptor(key: "transactionDate", ascending: sortedByDateAscending)
        return try expenseRepo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: - CREATE
    
    // MARK: create(description:amount:date:cardID:categoryID:recurrence:recurrenceEnd:secondBiMonthlyDay:secondBiMonthlyDate:parentID:)
    /// Create a new unplanned expense, linked to a card (and optionally category).
    /// - Parameters:
    ///   - descriptionText: Title/description. Will write to "descriptionText" if it exists; otherwise to "title".
    ///   - amount: Expense amount.
    ///   - date: Transaction date.
    ///   - cardID: The Card UUID this belongs to (required).
    ///   - categoryID: Optional ExpenseCategory UUID.
    ///   - recurrence: Optional recurrence key ("weekly","biweekly","monthly","semimonthly").
    ///   - recurrenceEnd: Optional recurrence end date.
    ///   - secondBiMonthlyDay: Optional: day-of-month (1...31) if your model uses an Int16 field.
    ///   - secondBiMonthlyDate: Optional: exact date if your model uses a Date field.
    ///   - parentID: Optional parent expense UUID (for split chains).
    @discardableResult
    func create(descriptionText: String,
                amount: Double,
                date: Date,
                cardID: UUID,
                categoryID: UUID? = nil,
                recurrence: String? = nil,
                recurrenceEnd: Date? = nil,
                secondBiMonthlyDay: Int16? = nil,
                secondBiMonthlyDate: Date? = nil,
                parentID: UUID? = nil) throws -> UnplannedExpense {
        guard let card = try cardRepo.fetchFirst(predicate: NSPredicate(format: "id == %@", cardID as CVarArg)) else {
            throw NSError(domain: "UnplannedExpenseService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Card not found: \(cardID)"])
        }
        let category: ExpenseCategory? = {
            guard let categoryID else { return nil }
            return try? categoryRepo.fetchFirst(predicate: NSPredicate(format: "id == %@", categoryID as CVarArg))
        }()
        
        let expense = expenseRepo.create { exp in
            // ✅ ID via KVC to avoid Identifiable ambiguity.
            exp.setValue(UUID(), forKey: "id")
            // Description drift
            Self.setDescription(on: exp, value: descriptionText)
            exp.amount = amount
            exp.transactionDate = date
            exp.recurrence = recurrence
            exp.recurrenceEndDate = recurrenceEnd
            // Set second bi-monthly via whichever attribute exists
            Self.setSecondBiMonthly(on: exp, day: secondBiMonthlyDay, date: secondBiMonthlyDate)
            // Relationships
            exp.setValue(card, forKey: "card")
            if let category { exp.setValue(category, forKey: "expenseCategory") }
            if let parentID { exp.setValue(parentID, forKey: "parentID") }
        }
        
        try expenseRepo.saveIfNeeded()
        return expense
    }
    
    // MARK: - UPDATE
    
    // MARK: update(_:description:amount:date:cardID:categoryID:recurrence:recurrenceEnd:secondBiMonthlyDay:secondBiMonthlyDate:parentID:)
    /// Update fields on an unplanned expense (only what you pass will change).
    func update(_ expense: UnplannedExpense,
                description: String? = nil,
                amount: Double? = nil,
                date: Date? = nil,
                cardID: UUID? = nil,
                categoryID: UUID?? = nil,
                recurrence: String? = nil,
                recurrenceEnd: Date?? = nil,
                secondBiMonthlyDay: Int16?? = nil,
                secondBiMonthlyDate: Date?? = nil,
                parentID: UUID?? = nil) throws {
        if let description { Self.setDescription(on: expense, value: description) }
        if let amount { expense.amount = amount }
        if let date { expense.transactionDate = date }
        
        if let cardID {
            if let card = try cardRepo.fetchFirst(predicate: NSPredicate(format: "id == %@", cardID as CVarArg)) {
                expense.setValue(card, forKey: "card")
            }
        }
        
        if let categoryID {
            if let cid = categoryID {
                // Set to specific category ID
                if let cat = try categoryRepo.fetchFirst(predicate: NSPredicate(format: "id == %@", cid as CVarArg)) {
                    expense.setValue(cat, forKey: "expenseCategory")
                }
            } else {
                // Explicitly clear the category
                expense.setValue(nil, forKey: "expenseCategory")
            }
        }
        
        if let recurrence { expense.recurrence = recurrence }
        if let recurrenceEnd { expense.recurrenceEndDate = recurrenceEnd }
        
        if let secondBiMonthlyDay {
            Self.setSecondBiMonthly(on: expense,
                                    day: secondBiMonthlyDay,
                                    date: secondBiMonthlyDate ?? nil)
        } else if let secondBiMonthlyDate {
            Self.setSecondBiMonthly(on: expense,
                                    day: nil,
                                    date: secondBiMonthlyDate)
        }
        
        if let parentID { expense.setValue(parentID, forKey: "parentID") }
        
        try expenseRepo.saveIfNeeded()
    }
    
    // MARK: - DELETE
    
    // MARK: delete(_:cascadeChildren:)
    /// Delete an unplanned expense, optionally deleting its children as well.
    func delete(_ expense: UnplannedExpense, cascadeChildren: Bool = true) throws {
        if cascadeChildren {
            let children = (expense.value(forKey: "childExpense") as? Set<UnplannedExpense>) ?? []
            for child in children { expenseRepo.delete(child) }
        }
        expenseRepo.delete(expense)
        try expenseRepo.saveIfNeeded()
    }
    
    // MARK: deleteAllForCard(_:)
    /// DANGER: Delete all unplanned expenses for a card (testing/reset).
    func deleteAllForCard(_ cardID: UUID) throws {
        let predicate = NSPredicate(format: "card.id == %@", cardID as CVarArg)
        try expenseRepo.deleteAll(predicate: predicate)
    }
    
    // MARK: - TOTALS
    
    // MARK: totalForCard(_:in:)
    /// Sum expense amounts for a card in a date interval.
    func totalForCard(_ cardID: UUID, in interval: DateInterval) throws -> Double {
        let items = try fetchForCard(cardID, in: interval, sortedByDateAscending: true)
        return items.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: totalForBudget(_:in:)
    /// Sum expense amounts for a budget in a date interval (via Card↔Budget link).
    func totalForBudget(_ budgetID: UUID, in interval: DateInterval) throws -> Double {
        let items = try fetchForBudget(budgetID, in: interval, sortedByDateAscending: true)
        return items.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - PARENT / CHILD HELPERS
    
    // MARK: addChild(_:child:)
    /// Link an existing child to a parent.
    func addChild(_ parent: UnplannedExpense, child: UnplannedExpense) throws {
        child.setValue(parent, forKey: "parentExpense")
        try expenseRepo.saveIfNeeded()
    }
    
    // MARK: children(of:)
    /// Fetch the direct children of a parent expense.
    func children(of parentID: UUID) throws -> [UnplannedExpense] {
        let predicate = NSPredicate(format: "parentExpense.id == %@", parentID as CVarArg)
        let sort = NSSortDescriptor(key: "transactionDate", ascending: true)
        return try expenseRepo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: split(_:parts:)
    /// Split an expense into multiple child entries. The original becomes a parent (amount may remain or be set to 0).
    /// - Parameters:
    ///   - expense: The original expense to split.
    ///   - parts: Array of partial entries (amount, optional categoryID, optional cardID override).
    ///   - zeroOutParent: If true, sets parent amount to 0 after splitting (default true).
    struct SplitPart {
        let amount: Double
        let categoryID: UUID?
        let cardID: UUID?
        let descriptionSuffix: String?  // e.g., "(groceries)", "(household)"
    }
    
    func split(_ expense: UnplannedExpense,
               parts: [SplitPart],
               zeroOutParent: Bool = true) throws -> [UnplannedExpense] {
        guard !parts.isEmpty else { return [] }
        let baseTitle = Self.getDescription(from: expense) ?? ""
        var created: [UnplannedExpense] = []
        let parentID = (expense.value(forKey: "id") as? UUID)
        
        for part in parts {
            let title = [baseTitle, part.descriptionSuffix].compactMap { $0 }.joined(separator: " ")
            let child = try create(descriptionText: title,
                                   amount: part.amount,
                                   date: expense.transactionDate ?? Date(),
                                   cardID: part.cardID ?? (expense.value(forKeyPath: "card.id") as? UUID) ?? { throw NSError(domain: "UnplannedExpenseService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing card on parent expense."]) }(),
                                   categoryID: part.categoryID,
                                   recurrence: nil,
                                   recurrenceEnd: nil,
                                   secondBiMonthlyDay: nil,
                                   secondBiMonthlyDate: nil,
                                   parentID: parentID)
            created.append(child)
        }
        
        if zeroOutParent {
            expense.amount = 0
            try expenseRepo.saveIfNeeded()
        }
        return created
    }
    
    // MARK: - CALENDAR HELPERS
    
    // MARK: events(in:includeProjectedRecurrences:)
    /// Return calendar-friendly events for all expenses in `interval`.
    /// If `includeProjectedRecurrences` is true, also returns non-persisted projected events based on recurrence.
    func events(in interval: DateInterval,
                includeProjectedRecurrences: Bool = true) throws -> [UnplannedEvent] {
        let base = try fetchRange(interval)
        
        var events: [UnplannedEvent] = base.map {
            UnplannedEvent(objectID: $0.objectID,
                           date: $0.transactionDate ?? Date.distantPast,
                           title: Self.getDescription(from: $0) ?? "",
                           amount: $0.amount,
                           isProjected: false)
        }
        
        guard includeProjectedRecurrences else { return events.sorted(by: { $0.date < $1.date }) }
        
        for exp in base {
            guard let recurrence = exp.recurrence?.lowercased(), !recurrence.isEmpty else { continue }
            let startDate = exp.transactionDate ?? Date()
            let lastDate = effectiveRecurrenceEndDate(for: exp, fallback: interval.end)
            let expansionWindow = DateInterval(start: interval.start, end: min(interval.end, lastDate))
            let (secondDay, secondDate) = Self.readSecondBiMonthly(on: exp)
            
            let projectedDates = expandRecurrence(recurrence,
                                                  baseDate: startDate,
                                                  in: expansionWindow,
                                                  calendar: calendar,
                                                  secondBiMonthlyDay: secondDay,
                                                  secondBiMonthlyDate: secondDate)
            for d in projectedDates {
                if calendar.isDate(d, inSameDayAs: startDate) { continue }
                events.append(UnplannedEvent(objectID: nil,
                                             date: d,
                                             title: Self.getDescription(from: exp) ?? "",
                                             amount: exp.amount,
                                             isProjected: true))
            }
        }
        
        return events.sorted { $0.date < $1.date }
    }
    
    // MARK: eventsByDay(in:)
    /// Group events by day for calendar cells/dots.
    func eventsByDay(in interval: DateInterval,
                     includeProjectedRecurrences: Bool = true) throws -> [Date: [UnplannedEvent]] {
        let evs = try events(in: interval, includeProjectedRecurrences: includeProjectedRecurrences)
        var grouped: [Date: [UnplannedEvent]] = [:]
        for e in evs {
            let day = calendar.startOfDay(for: e.date)
            grouped[day, default: []].append(e)
        }
        return grouped
    }
    
    // MARK: eventsByDay(inMonthContaining:)
    /// Convenience for a whole month containing the given date.
    func eventsByDay(inMonthContaining date: Date,
                     includeProjectedRecurrences: Bool = true) throws -> [Date: [UnplannedEvent]] {
        let month = monthInterval(containing: date)
        return try eventsByDay(in: month, includeProjectedRecurrences: includeProjectedRecurrences)
    }
    
    // MARK: - Internal: Range fetch (used by calendar helpers)
    private func fetchRange(_ interval: DateInterval) throws -> [UnplannedExpense] {
        let predicate = NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@",
                                    interval.start as CVarArg, interval.end as CVarArg)
        let sort = NSSortDescriptor(key: "transactionDate", ascending: true)
        return try expenseRepo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: - Recurrence Utilities
    
    private func expandRecurrence(_ recurrence: String,
                                  baseDate: Date,
                                  in interval: DateInterval,
                                  calendar: Calendar,
                                  secondBiMonthlyDay: Int16?,
                                  secondBiMonthlyDate: Date?) -> [Date] {
        let lower = recurrence.lowercased()
        switch lower {
        case "weekly":
            return strideDates(start: baseDate, stepDays: 7, within: interval, calendar: calendar)
        case "biweekly":
            return strideDates(start: baseDate, stepDays: 14, within: interval, calendar: calendar)
        case "monthly":
            return strideMonthly(start: baseDate, within: interval, calendar: calendar)
        case "semimonthly":
            // Prefer explicit Date if provided; else use day-of-month heuristic.
            if let explicitDate = secondBiMonthlyDate {
                return strideSemiMonthly(start: baseDate, within: interval, calendar: calendar, secondDate: explicitDate)
            }
            return strideSemiMonthlyUsingDay(start: baseDate,
                                             within: interval,
                                             calendar: calendar,
                                             secondDay: secondBiMonthlyDay)
        default:
            return []
        }
    }
    
    private func effectiveRecurrenceEndDate(for expense: UnplannedExpense, fallback: Date) -> Date {
        if let end = expense.recurrenceEndDate { return min(end, fallback) }
        return fallback
    }
    
    private func monthInterval(containing date: Date) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        let comps = DateComponents(month: 1, second: -1)
        let end = calendar.date(byAdding: comps, to: start) ?? date
        return DateInterval(start: start, end: end)
    }
    
    private func strideDates(start: Date, stepDays: Int, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = start
        if current < interval.start {
            let deltaDays = calendar.dateComponents([.day], from: start, to: interval.start).day ?? 0
            let steps = (deltaDays + stepDays - 1) / stepDays
            current = calendar.date(byAdding: .day, value: steps * stepDays, to: start) ?? interval.start
        }
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: current) else { break }
            current = next
        }
        return dates
    }
    
    private func strideMonthly(start: Date, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = alignedToInterval(start: start, unit: .month, within: interval, calendar: calendar)
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }
    
    // Semimonthly: explicit second Date (same day-of-month is used each month, clamped)
    private func strideSemiMonthly(start: Date,
                                   within interval: DateInterval,
                                   calendar: Calendar,
                                   secondDate: Date) -> [Date] {
        var results: [Date] = []
        let baseDay = calendar.component(.day, from: start)
        let secondDay = calendar.component(.day, from: secondDate)
        
        var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: max(start, interval.start))) ?? calendar.startOfDay(for: start)
        while monthStart <= interval.end {
            if let d1 = clampedDayInMonth(baseDay, near: monthStart, calendar: calendar),
               interval.contains(d1), d1 >= start { results.append(d1) }
            if let d2 = clampedDayInMonth(secondDay, near: monthStart, calendar: calendar),
               interval.contains(d2), d2 >= start { results.append(d2) }
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return results.sorted()
    }
    
    // Semimonthly: use day-of-month (or infer 1st/15th-like behavior)
    private func strideSemiMonthlyUsingDay(start: Date,
                                           within interval: DateInterval,
                                           calendar: Calendar,
                                           secondDay: Int16?) -> [Date] {
        var results: [Date] = []
        let baseDay = calendar.component(.day, from: start)
        let second = Int(secondDay ?? Int16(max(1, min(28, baseDay <= 15 ? 30 : 15))))
        
        var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: max(start, interval.start))) ?? calendar.startOfDay(for: start)
        while monthStart <= interval.end {
            if let d1 = clampedDayInMonth(baseDay, near: monthStart, calendar: calendar),
               interval.contains(d1), d1 >= start { results.append(d1) }
            if let d2 = clampedDayInMonth(second, near: monthStart, calendar: calendar),
               interval.contains(d2), d2 >= start { results.append(d2) }
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return results.sorted()
    }
    
    private func alignedToInterval(start: Date,
                                   unit: Calendar.Component,
                                   within interval: DateInterval,
                                   calendar: Calendar) -> Date {
        var current = start
        while current < interval.start {
            guard let next = calendar.date(byAdding: unit, value: 1, to: current) else { break }
            current = next
        }
        return current
    }
    
    private func clampedDayInMonth(_ day: Int, near monthAnchor: Date, calendar: Calendar) -> Date? {
        // Range<Int> fallback (half-open), see IncomeService fix.
        let range = calendar.range(of: .day, in: .month, for: monthAnchor) ?? (1..<29)
        let lastValid = max(range.lowerBound, range.upperBound - 1)
        let clamped = max(range.lowerBound, min(day, lastValid))
        var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        comps.day = clamped
        return calendar.date(from: comps)
    }
    
    // MARK: - Schema Drift Helpers
    
    // Description: prefer "descriptionText", fallback to "title"
    private static func setDescription(on object: NSManagedObject, value: String) {
        let keys = object.entity.attributesByName.keys
        if keys.contains("descriptionText") {
            object.setValue(value, forKey: "descriptionText")
        } else if keys.contains("title") {
            object.setValue(value, forKey: "title")
        }
    }
    
    private static func getDescription(from object: NSManagedObject) -> String? {
        let keys = object.entity.attributesByName.keys
        if keys.contains("descriptionText") {
            return object.value(forKey: "descriptionText") as? String
        } else if keys.contains("title") {
            return object.value(forKey: "title") as? String
        }
        return nil
    }
    
    // Second bi-monthly: support either Date("secondBiMonthlyDate") or Int16("secondBiMonthlyDay"/"secondPayDay")
    private static func setSecondBiMonthly(on object: NSManagedObject,
                                           day: Int16?,
                                           date: Date?) {
        let keys = object.entity.attributesByName.keys
        if let date, keys.contains("secondBiMonthlyDate") {
            object.setValue(date, forKey: "secondBiMonthlyDate")
            return
        }
        if let day {
            for k in ["secondBiMonthlyDay", "secondPayDay", "secondBiMonthlyPayDay"] where keys.contains(k) {
                object.setValue(day, forKey: k)
                return
            }
        }
    }
    
    private static func readSecondBiMonthly(on object: NSManagedObject) -> (Int16?, Date?) {
        let keys = object.entity.attributesByName.keys
        if keys.contains("secondBiMonthlyDate"), let d = object.value(forKey: "secondBiMonthlyDate") as? Date {
            return (nil, d)
        }
        for k in ["secondBiMonthlyDay", "secondPayDay", "secondBiMonthlyPayDay"] where keys.contains(k) {
            if let v = object.value(forKey: k) as? Int16 { return (v, nil) }
        }
        return (nil, nil)
    }
}
