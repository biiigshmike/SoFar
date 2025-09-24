//
//  IncomeScreenViewModel.swift
//  SoFar
//
//  Holds selected date, fetches incomes for the date, and performs CRUD via IncomeService.
//

import Foundation
import CoreData

// MARK: - IncomeScreenViewModel
@MainActor
final class IncomeScreenViewModel: ObservableObject {
    // MARK: Public, @Published
    @Published var selectedDate: Date? = Date()
    @Published private(set) var incomesForDay: [Income] = []
    @Published private(set) var plannedTotalForSelectedDate: Double = 0
    @Published private(set) var actualTotalForSelectedDate: Double = 0
    @Published private(set) var totalForSelectedDate: Double = 0
    @Published private(set) var plannedTotalForSelectedWeek: Double = 0
    @Published private(set) var actualTotalForSelectedWeek: Double = 0
    @Published private(set) var totalForSelectedWeek: Double = 0
    @Published private(set) var eventsByDay: [Date: [IncomeService.IncomeEvent]] = [:]
    
    // MARK: Private
    private let incomeService: IncomeService
    private let calendar: Calendar = .current

    /// Cache of month-start anchors → day/event mappings to avoid re-fetching
    /// the entire multi-year range on every selection change. Each entry holds
    /// the results of `IncomeService.eventsByDay(inMonthContaining:)`.
    private var cachedMonthlyEvents: [Date: [Date: [IncomeService.IncomeEvent]]] = [:]

    /// Maximum number of distinct months to keep in memory at once. Older
    /// months are pruned when this limit is exceeded.
    private let maxCachedMonths: Int = 6
    
    // MARK: Init
    init(incomeService: IncomeService = IncomeService()) {
        self.incomeService = incomeService
    }
    
    // MARK: Titles
    var selectedDateTitle: String {
        guard let d = selectedDate else { return "—" }
        return DateFormatter.localizedString(from: d, dateStyle: .full, timeStyle: .none)
    }
    
    var totalForSelectedDateText: String {
        NumberFormatter.currency.string(from: totalForSelectedDate as NSNumber) ?? ""
    }
    
    // MARK: Loading
    func reloadForSelectedDay(forceMonthReload: Bool = false) {
        guard let d = selectedDate else { return }
        load(day: d, forceMonthReload: forceMonthReload)
    }

    func load(day: Date, forceMonthReload: Bool = false) {
        do {
            incomesForDay = try incomeService.fetchIncomes(on: day)

            let dayTotals = totals(from: incomesForDay)
            plannedTotalForSelectedDate = dayTotals.planned
            actualTotalForSelectedDate = dayTotals.actual
            totalForSelectedDate = dayTotals.planned + dayTotals.actual

            let weekTotals = try totalsForWeek(containing: day)
            plannedTotalForSelectedWeek = weekTotals.planned
            actualTotalForSelectedWeek = weekTotals.actual
            totalForSelectedWeek = weekTotals.planned + weekTotals.actual
            refreshEventsCache(for: day, force: forceMonthReload)
        } catch {
            AppLog.viewModel.error("Income fetch error: \(String(describing: error))")
            incomesForDay = []
            plannedTotalForSelectedDate = 0
            actualTotalForSelectedDate = 0
            totalForSelectedDate = 0
            plannedTotalForSelectedWeek = 0
            actualTotalForSelectedWeek = 0
            totalForSelectedWeek = 0
            eventsByDay = [:]
            cachedMonthlyEvents.removeAll()
        }
    }

    // MARK: CRUD
    func delete(income: Income, scope: RecurrenceScope = .all) {
        do {
            try incomeService.deleteIncome(income, scope: scope)
            let day = selectedDate ?? income.date ?? Date()
            if scope == .future || scope == .all {
                clearEventCaches()
            }
            load(day: day, forceMonthReload: true)
        } catch {
            AppLog.viewModel.error("Income delete error: \(String(describing: error))")
        }
    }
    
    // MARK: Formatting
    func currencyString(for amount: Double) -> String {
        NumberFormatter.currency.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }

    // MARK: Events Summary
    func summary(for date: Date) -> (planned: Double, actual: Double)? {
        let day = calendar.startOfDay(for: date)
        guard let events = eventsByDay[day] else { return nil }
        let planned = events.filter { $0.isPlanned }.reduce(0) { $0 + $1.amount }
        let actual = events.filter { !$0.isPlanned }.reduce(0) { $0 + $1.amount }
        if planned == 0 && actual == 0 { return nil }
        return (planned, actual)
    }

    // MARK: - Event Cache Management
    /// Refreshes the cached calendar events for the month containing `date`.
    /// When `force` is `true` the month is re-fetched even if it already
    /// exists in the cache.
    private func refreshEventsCache(for date: Date, force: Bool) {
        let monthAnchor = monthStart(for: date)
        if !force, cachedMonthlyEvents[monthAnchor] != nil {
            // Still prefetch adjacent months if they aren't cached yet.
            prefetchAdjacentMonths(from: date)
            return
        }

        if let monthEvents = try? incomeService.eventsByDay(inMonthContaining: date) {
            cachedMonthlyEvents[monthAnchor] = monthEvents
            trimCacheIfNeeded()
            rebuildEventsByDay()
        }

        prefetchAdjacentMonths(from: date)
    }

    /// Prefetch the previous and next months when they are not already cached
    /// to keep calendar scrolling responsive.
    private func prefetchAdjacentMonths(from date: Date) {
        if let previous = calendar.date(byAdding: .month, value: -1, to: date) {
            _ = ensureMonthCached(for: previous)
        }
        if let next = calendar.date(byAdding: .month, value: 1, to: date) {
            _ = ensureMonthCached(for: next)
        }
    }

    /// Ensures the month containing `date` is cached. Returns `true` when a
    /// fetch occurred.
    @discardableResult
    private func ensureMonthCached(for date: Date) -> Bool {
        let monthAnchor = monthStart(for: date)
        guard cachedMonthlyEvents[monthAnchor] == nil else { return false }
        guard let monthEvents = try? incomeService.eventsByDay(inMonthContaining: date) else {
            return false
        }
        cachedMonthlyEvents[monthAnchor] = monthEvents
        trimCacheIfNeeded()
        rebuildEventsByDay()
        return true
    }

    /// Removes older cached months when the limit is exceeded.
    private func trimCacheIfNeeded() {
        guard cachedMonthlyEvents.count > maxCachedMonths else { return }
        let sortedKeys = cachedMonthlyEvents.keys.sorted()
        let overflow = cachedMonthlyEvents.count - maxCachedMonths
        for key in sortedKeys.prefix(overflow) {
            cachedMonthlyEvents.removeValue(forKey: key)
        }
    }

    /// Rebuilds the published `eventsByDay` dictionary from the cached months.
    private func rebuildEventsByDay() {
        eventsByDay = cachedMonthlyEvents.values.reduce(into: [:]) { partial, monthMap in
            for (day, events) in monthMap {
                partial[day] = events
            }
        }
    }

    /// Clears all cached month data and published summaries.
    private func clearEventCaches() {
        cachedMonthlyEvents.removeAll()
        eventsByDay = [:]
    }

    /// Normalized start-of-month date for caching keys.
    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        ?? calendar.startOfDay(for: date)
    }

    /// Calculates the totals for the provided incomes, broken out by planned vs actual.
    private func totals(from incomes: [Income]) -> (planned: Double, actual: Double) {
        incomes.reduce(into: (planned: 0.0, actual: 0.0)) { partial, income in
            if income.isPlanned {
                partial.planned += income.amount
            } else {
                partial.actual += income.amount
            }
        }
    }

    /// Calculates the sum of incomes for the week containing the provided date, separated by planned/actual.
    private func totalsForWeek(containing date: Date) throws -> (planned: Double, actual: Double) {
        guard let interval = weekInterval(containing: date) else { return (0, 0) }
        let incomes = try incomeService.fetchIncomes(in: interval)
        return totals(from: incomes)
    }

    /// Returns the closed date interval for the week containing `date` using a Sunday-based calendar.
    private func weekInterval(containing date: Date) -> DateInterval? {
        var cal = calendar
        cal.firstWeekday = 1
        guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start,
              let end = cal.date(byAdding: DateComponents(day: 7, second: -1), to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }
}

// MARK: - Currency NumberFormatter
private extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
}
