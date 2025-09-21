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
    @Published private(set) var totalForSelectedDate: Double = 0
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
            totalForSelectedDate = incomesForDay.reduce(0) { $0 + $1.amount }
            totalForSelectedWeek = try totalIncomeForWeek(containing: day)
            refreshEventsCache(for: day, force: forceMonthReload)
        } catch {
            #if DEBUG
            print("Income fetch error:", error)
            #endif
            incomesForDay = []
            totalForSelectedDate = 0
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
            #if DEBUG
            print("Income delete error:", error)
            #endif
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

    /// Computes the inclusive start/end of the week containing `date` and
    /// returns the aggregated income total.
    private func totalIncomeForWeek(containing date: Date) throws -> Double {
        guard let rawInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return totalForSelectedDate
        }

        let inclusiveEnd = calendar.date(byAdding: DateComponents(second: -1), to: rawInterval.end)
            ?? rawInterval.end

        let interval = DateInterval(start: rawInterval.start, end: inclusiveEnd)
        let incomes = try incomeService.fetchIncomes(in: interval)
        return incomes.reduce(0) { $0 + $1.amount }
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
