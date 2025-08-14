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
        try repo.saveIfNeeded()
    }
    
    // MARK: deleteIncome(_:)
    /// Delete an income record.
    func deleteIncome(_ income: Income) throws {
        repo.delete(income)
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
    /// If `includeProjectedRecurrences` is true, also returns non-persisted “projected” events
    /// that fall inside the interval based on simple recurrence rules.
    func events(in interval: DateInterval,
                includeProjectedRecurrences: Bool = true) throws -> [IncomeEvent] {
        let base = try fetchIncomes(in: interval)
        
        var events: [IncomeEvent] = base.map {
            IncomeEvent(objectID: $0.objectID,
                        date: $0.date ?? Date.distantPast,
                        source: $0.source ?? "",
                        amount: $0.amount,
                        isPlanned: $0.isPlanned,
                        isProjected: false)
        }
        
        guard includeProjectedRecurrences else { return events }
        
        // Expand recurrences for items whose base date is <= interval.end.
        for inc in base {
            guard let recurrence = inc.recurrence?.lowercased(), !recurrence.isEmpty else { continue }
            let startDate = inc.date ?? Date()
            let lastDate = effectiveRecurrenceEndDate(for: inc, fallback: interval.end)
            let expansionWindow = DateInterval(start: interval.start, end: min(interval.end, lastDate))
            let secondDay = Self.optionalInt16IfAttributeExists(on: inc, keyCandidates: ["secondPayDay", "secondBiMonthlyPayDay"])
            
            let projectedDates = expandRecurrence(recurrence,
                                                  baseDate: startDate,
                                                  in: expansionWindow,
                                                  calendar: calendar,
                                                  secondBiMonthlyDay: secondDay)
            for d in projectedDates {
                // Skip the base persisted date to avoid duplicates.
                if calendar.isDate(d, inSameDayAs: startDate) { continue }
                events.append(IncomeEvent(objectID: nil,
                                          date: d,
                                          source: inc.source ?? "",
                                          amount: inc.amount,
                                          isPlanned: inc.isPlanned,
                                          isProjected: true))
            }
        }
        
        // Sort by date ASC for stable rendering
        events.sort { $0.date < $1.date }
        return events
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
    
    // MARK: expandRecurrence(_:baseDate:in:calendar:secondBiMonthlyDay:)
    /// Expand a simple recurrence into concrete dates within the given interval.
    private func expandRecurrence(_ recurrence: String,
                                  baseDate: Date,
                                  in interval: DateInterval,
                                  calendar: Calendar,
                                  secondBiMonthlyDay: Int16?) -> [Date] {
        let lower = recurrence.lowercased()
        switch lower {
        case "weekly":
            return strideDates(start: baseDate, stepDays: 7, within: interval, calendar: calendar)
        case "biweekly":
            return strideDates(start: baseDate, stepDays: 14, within: interval, calendar: calendar)
        case "monthly":
            return strideMonthly(start: baseDate, within: interval, calendar: calendar)
        case "semimonthly":
            return strideSemiMonthly(start: baseDate,
                                     within: interval,
                                     calendar: calendar,
                                     secondDay: secondBiMonthlyDay)
        default:
            return []
        }
    }
    
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
    
    // MARK: strideDates(start:stepDays:within:calendar:)
    private func strideDates(start: Date, stepDays: Int, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        // Ensure the first stepping point is not before interval.start
        var current = start
        if current < interval.start {
            // Align forward to the first occurrence >= interval.start
            let deltaDays = calendar.dateComponents([.day], from: start, to: interval.start).day ?? 0
            let steps = (deltaDays + stepDays - 1) / stepDays // ceil division
            current = calendar.date(byAdding: .day, value: steps * stepDays, to: start) ?? interval.start
        }
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: current) else { break }
            current = next
        }
        return dates
    }
    
    // MARK: strideMonthly(start:within:calendar:)
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
    
    // MARK: strideSemiMonthly(start:within:calendar:secondDay:)
    /// Generate two dates per month: the day-of-month from `start` and the `secondDay` if provided.
    /// If `secondDay` is nil, falls back to 1st and 15th-like behavior inferred from `start`'s day.
    private func strideSemiMonthly(start: Date,
                                   within interval: DateInterval,
                                   calendar: Calendar,
                                   secondDay: Int16?) -> [Date] {
        var results: [Date] = []
        let baseDay = calendar.component(.day, from: start)
        let second = Int(secondDay ?? Int16(max(1, min(28, baseDay <= 15 ? 30 : 15))))
        
        // Start at the first month where either occurrence falls within the interval.
        var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: max(start, interval.start))) ?? calendar.startOfDay(for: start)
        
        while monthStart <= interval.end {
            // First occurrence: the base day (clamped to month length)
            if let d1 = clampedDayInMonth(baseDay, near: monthStart, calendar: calendar),
               interval.contains(d1), d1 >= start {
                results.append(d1)
            }
            // Second occurrence: specified second day (clamped)
            if let d2 = clampedDayInMonth(second, near: monthStart, calendar: calendar),
               interval.contains(d2), d2 >= start {
                results.append(d2)
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = nextMonth
        }
        return results.sorted()
    }
    
    // MARK: alignedToInterval(start:unit:within:calendar:)
    private func alignedToInterval(start: Date,
                                   unit: Calendar.Component,
                                   within interval: DateInterval,
                                   calendar: Calendar) -> Date {
        // Advance forward in `unit` steps until we are within the interval.
        var current = start
        while current < interval.start {
            guard let next = calendar.date(byAdding: unit, value: 1, to: current) else { break }
            current = next
        }
        return current
    }
    
    // MARK: clampedDayInMonth(_:near:calendar:)
    private func clampedDayInMonth(_ day: Int, near monthAnchor: Date, calendar: Calendar) -> Date? {
        // Use half-open range (Range<Int>) to match Calendar.range(...) signature.
        // Fallback to 1..<29 instead of 1...28 to avoid ClosedRange/Range mismatch.
        let range = calendar.range(of: .day, in: .month, for: monthAnchor) ?? (1..<29)
        // Since Range upperBound is exclusive, last valid day is (upperBound - 1).
        let lastValid = max(range.lowerBound, range.upperBound - 1)
        let clamped = max(range.lowerBound, min(day, lastValid))
        
        var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        comps.day = clamped
        // Keep the time of day as 00:00 for clean calendar grouping
        return calendar.date(from: comps)
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
