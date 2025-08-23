//
//  IncomeService.swift
//  SoFar
//
//  Purpose:
//  - CRUD for Income entities
//  - Calendar-friendly helpers: fetch by range/month, group by day,
//    and (optionally) expand simple recurrence patterns for display.
//

import Foundation
import CoreData

// MARK: - IncomeService
final class IncomeService {
    
    // MARK: Types
    struct IncomeEvent: Hashable {
        let objectID: NSManagedObjectID?
        let date: Date
        let source: String
        let amount: Double
        let isPlanned: Bool
        let isProjected: Bool
    }
    
    // MARK: Properties
    private let repo: CoreDataRepository<Income>
    private let calendar: Calendar
    
    // MARK: Init
    init(stack: CoreDataStackProviding = CoreDataService.shared,
         calendar: Calendar = .current) {
        self.repo = CoreDataRepository<Income>(stack: stack)
        self.calendar = calendar
    }
    
    // MARK: - CRUD
    
    // MARK: fetchAllIncomes(sortedByDateAscending:)
    /// Fetch all incomes in the store.
    /// - Parameter sortedByDateAscending: Sort by `date` ascending if true (default true).
    func fetchAllIncomes(sortedByDateAscending: Bool = true) throws -> [Income] {
        let sort = NSSortDescriptor(key: #keyPath(Income.date), ascending: sortedByDateAscending)
        return try repo.fetchAll(sortDescriptors: [sort])
    }
    
    // MARK: fetchIncomes(in:)
    /// Fetch incomes within a date interval (inclusive of boundaries).
    /// - Parameter interval: DateInterval to search.
    func fetchIncomes(in interval: DateInterval) throws -> [Income] {
        let predicate = NSPredicate(format: "(%K >= %@) AND (%K <= %@)",
                                    #keyPath(Income.date), interval.start as CVarArg,
                                    #keyPath(Income.date), interval.end as CVarArg)
        let sort = NSSortDescriptor(key: #keyPath(Income.date), ascending: true)
        return try repo.fetchAll(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: fetchIncomes(on:)
    /// Fetch incomes on a specific day (calendar day).
    func fetchIncomes(on day: Date) throws -> [Income] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) else {
            return []
        }
        return try fetchIncomes(in: DateInterval(start: dayStart, end: dayEnd))
    }
    
    // MARK: findIncome(byID:)
    /// Find a single income by UUID.
    func findIncome(byID id: UUID) throws -> Income? {
        // ✅ Literal "id" avoids ambiguity with Identifiable.
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try repo.fetchFirst(predicate: predicate)
    }
    
    // MARK: createIncome(...)
    /// Create a new income record.
    /// - Parameters:
    ///   - source: e.g., "Paycheck", "Freelance", etc.
    ///   - amount: Gross amount for the event.
    ///   - date: The primary date (first occurrence for recurrence patterns).
    ///   - isPlanned: Whether this is planned/expected income.
    ///   - recurrence: Optional recurrence key ("weekly","biweekly","monthly","semimonthly").
    ///   - recurrenceEndDate: Optional end date for recurrence.
    ///   - secondBiMonthlyDay: Optional, used when `recurrence == "semimonthly"`. Day-of-month (1...31).
    /// - Returns: The created Income.
    @discardableResult
    func createIncome(source: String,
                      amount: Double,
                      date: Date,
                      isPlanned: Bool,
                      recurrence: String? = nil,
                      recurrenceEndDate: Date? = nil,
                      secondBiMonthlyDay: Int16? = nil) throws -> Income {
        let income = repo.create { inc in
            // ✅ Assign via KVC to avoid `.id` ambiguity.
            inc.setValue(UUID(), forKey: "id")
            inc.source = source
            inc.amount = amount
            inc.date = date
            inc.isPlanned = isPlanned
            inc.recurrence = recurrence
            inc.recurrenceEndDate = recurrenceEndDate
            // Safely set either "secondPayDay" or "secondBiMonthlyPayDay" if present.
            Self.setOptionalInt16IfAttributeExists(on: inc,
                                                   keyCandidates: ["secondPayDay", "secondBiMonthlyPayDay"],
                                                   value: secondBiMonthlyDay)
        }
        try RecurrenceEngine.regenerateIncomeRecurrences(base: income, in: repo.context)
        try repo.saveIfNeeded()
        return income
    }
    
    // MARK: updateIncome(_:...)
    /// Update fields of an income. Pass only what you want to change.
    func updateIncome(_ income: Income,
                      source: String? = nil,
                      amount: Double? = nil,
                      date: Date? = nil,
                      isPlanned: Bool? = nil,
                      recurrence: String? = nil,
                      recurrenceEndDate: Date?? = nil,
                      secondBiMonthlyDay: Int16?? = nil) throws {
        if let source { income.source = source }
        if let amount { income.amount = amount }
        if let date { income.date = date }
        if let isPlanned { income.isPlanned = isPlanned }
        if let recurrence { income.recurrence = recurrence }
        if let recurrenceEndDate { income.recurrenceEndDate = recurrenceEndDate }
        if let secondBiMonthlyDay {
            Self.setOptionalInt16IfAttributeExists(on: income,
                                                   keyCandidates: ["secondPayDay", "secondBiMonthlyPayDay"],
                                                   value: secondBiMonthlyDay)
        }
        try RecurrenceEngine.regenerateIncomeRecurrences(base: income, in: repo.context)
        try repo.saveIfNeeded()
    }
    
    // MARK: deleteIncome(_:scope:)
    enum DeletionScope {
        case instance
        case future
        case all
    }

    /// Delete an income record with optional series scope.
    func deleteIncome(_ income: Income, scope: DeletionScope = .instance) throws {
        let context = repo.context
        let date = income.date ?? Date.distantPast
        let seriesID = income.parentID ?? income.id

        switch scope {
        case .instance:
            repo.delete(income)
        case .future:
            if let id = seriesID {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "(id == %@ OR parentID == %@) AND date >= %@", id as CVarArg, id as CVarArg, date as CVarArg)
                let targets = try context.fetch(request)
                for t in targets { repo.delete(t) }
            } else {
                repo.delete(income)
            }
        case .all:
            if let id = seriesID {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@ OR parentID == %@", id as CVarArg, id as CVarArg)
                let targets = try context.fetch(request)
                for t in targets { repo.delete(t) }
            } else {
                repo.delete(income)
            }
        }
        try repo.saveIfNeeded()
    }
    
    // MARK: deleteAllIncomes()
    /// DANGER: Delete all incomes. Use for testing/reset only.
    func deleteAllIncomes() throws {
        try repo.deleteAll()
    }
    
    // MARK: - Calendar Helpers
    
    // MARK: events(in:includeProjectedRecurrences:)
    /// Return calendar-friendly events for all incomes in `interval`.
    /// Recurrent incomes are already persisted, so this simply maps each Income to an `IncomeEvent`.
    func events(in interval: DateInterval,
                includeProjectedRecurrences: Bool = true) throws -> [IncomeEvent] {
        let base = try fetchIncomes(in: interval)
        let events: [IncomeEvent] = base.map {
            IncomeEvent(objectID: $0.objectID,
                        date: $0.date ?? Date.distantPast,
                        source: $0.source ?? "",
                        amount: $0.amount,
                        isPlanned: $0.isPlanned,
                        isProjected: false)
        }
        return events.sorted { $0.date < $1.date }
    }
    
    // MARK: eventsByDay(in:)
    /// Return events grouped by day for a date interval—perfect for calendar dots/cells.
    func eventsByDay(in interval: DateInterval,
                     includeProjectedRecurrences: Bool = true) throws -> [Date: [IncomeEvent]] {
        let events = try self.events(in: interval, includeProjectedRecurrences: includeProjectedRecurrences)
        var grouped: [Date: [IncomeEvent]] = [:]
        for e in events {
            let day = calendar.startOfDay(for: e.date)
            grouped[day, default: []].append(e)
        }
        return grouped
    }
    
    // MARK: eventsByDay(inMonthContaining:)
    /// Convenience: get events grouped by each day in the month that contains `date`.
    func eventsByDay(inMonthContaining date: Date,
                     includeProjectedRecurrences: Bool = true) throws -> [Date: [IncomeEvent]] {
        let monthInterval = monthInterval(containing: date)
        return try eventsByDay(in: monthInterval, includeProjectedRecurrences: includeProjectedRecurrences)
    }
    
    // MARK: totalAmount(in:includePlanned:)
    /// Sum income amounts in a date interval.
    /// - Parameters:
    ///   - interval: Date range.
    ///   - includePlanned: If non-nil, filter by `isPlanned` == value.
    func totalAmount(in interval: DateInterval, includePlanned: Bool? = nil) throws -> Double {
        let incomes = try fetchIncomes(in: interval).filter { inc in
            guard let includePlanned = includePlanned else { return true }
            return inc.isPlanned == includePlanned
        }
        return incomes.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Private: Recurrence & Date Utilities

    // MARK: effectiveRecurrenceEndDate(for:fallback:)
    /// Choose the earlier of (income.recurrenceEndDate or fallback).
    private func effectiveRecurrenceEndDate(for income: Income, fallback: Date) -> Date {
        if let end = income.recurrenceEndDate { return min(end, fallback) }
        return fallback
    }
    
    // MARK: monthInterval(containing:)
    /// Full month interval (start of month ... end of month).
    private func monthInterval(containing date: Date) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        let comps = DateComponents(month: 1, second: -1)
        let end = calendar.date(byAdding: comps, to: start) ?? date
        return DateInterval(start: start, end: end)
    }
    
    // MARK: - Safe KVC helpers for schema drift
    
    // MARK: setOptionalInt16IfAttributeExists(on:keyCandidates:value:)
    /// Sets an optional Int16 value on the first existing attribute key in `keyCandidates`.
    private static func setOptionalInt16IfAttributeExists(on object: NSManagedObject,
                                                          keyCandidates: [String],
                                                          value: Int16?) {
        guard let value = value else { return }
        for key in keyCandidates {
            if object.entity.attributesByName.keys.contains(key) {
                object.setValue(value, forKey: key)
                return
            }
        }
    }
    
    // MARK: optionalInt16IfAttributeExists(on:keyCandidates:)
    /// Reads an optional Int16 value from the first existing attribute key in `keyCandidates`.
    private static func optionalInt16IfAttributeExists(on object: NSManagedObject,
                                                       keyCandidates: [String]) -> Int16? {
        for key in keyCandidates {
            if object.entity.attributesByName.keys.contains(key) {
                return object.value(forKey: key) as? Int16
            }
        }
        return nil
    }
}
