//
//  BudgetDetailsViewModel.swift
//  SoFar
//
//  View model for Budget Details. Loads a budget by objectID,
//  fetches planned & unplanned expenses in the current filter window,
//  and exposes filtered/sorted arrays for display.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - BudgetDetailsViewModel
@MainActor
final class BudgetDetailsViewModel: ObservableObject {

    // MARK: Inputs
    let budgetObjectID: NSManagedObjectID

    // MARK: Core Data
    private let context: NSManagedObjectContext
    @Published private(set) var budget: Budget?

    // Services
    private let unplannedService = UnplannedExpenseService()

    // MARK: Filter/Search/Sort
    enum Segment: String, CaseIterable, Identifiable { case planned, variable; var id: String { rawValue } }
    enum SortOption: String, CaseIterable, Identifiable {
        case titleAZ, amountLowHigh, amountHighLow, dateOldNew, dateNewOld
        var id: String { rawValue }
    }

    struct BudgetDetailsAlert: Identifiable {
        enum Kind {
            case error(message: String)
        }
        let id = UUID()
        let kind: Kind
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    @Published var selectedSegment: Segment = .planned
    @Published var searchQuery: String = ""

    // MARK: Date Window
    @Published var startDate: Date = Date() // set after load
    @Published var endDate: Date = Date()   // set after load
    private var didInitializeDateWindow = false

    // MARK: Sort
    @Published var sort: SortOption = .dateNewOld

    // MARK: Loaded data (raw)
    @Published private(set) var plannedExpenses: [PlannedExpense] = []
    @Published private(set) var unplannedExpenses: [UnplannedExpense] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published var alert: BudgetDetailsAlert?

    /// Tracks the first load to avoid resetting `loadState` if multiple observers request it simultaneously.
    private var isInitialLoadInFlight = false
    private var isLoadInFlight = false
    private var shouldReloadAfterCurrentRun = false

    struct IncomeTotals: Equatable {
        var planned: Double
        var actual: Double

        static let zero = IncomeTotals(planned: 0, actual: 0)
    }
    @Published private(set) var incomeTotals: IncomeTotals = .zero

    // MARK: Summary
    /// Computed summary of totals used by the header.
    var summary: BudgetSummary? {
        guard let budget else { return nil }

        let plannedPlanned = plannedExpenses.reduce(0) { $0 + $1.plannedAmount }
        let plannedActual  = plannedExpenses.reduce(0) { $0 + $1.actualAmount }

        var categoryMap: [String: (hex: String?, total: Double)] = [:]
        var variableTotal: Double = 0

        for e in plannedExpenses {
            let amt = e.actualAmount
            let name = e.expenseCategory?.name ?? "Uncategorized"
            let hex = e.expenseCategory?.color
            let existing = categoryMap[name] ?? (hex: hex, total: 0)
            categoryMap[name] = (hex: hex ?? existing.hex, total: existing.total + amt)
        }

        for e in unplannedExpenses {
            let amt = e.amount
            variableTotal += amt
            let name = e.expenseCategory?.name ?? "Uncategorized"
            let hex = e.expenseCategory?.color
            let existing = categoryMap[name] ?? (hex: hex, total: 0)
            categoryMap[name] = (hex: hex ?? existing.hex, total: existing.total + amt)
        }
        let categoryBreakdown = categoryMap
            .map { BudgetSummary.CategorySpending(categoryName: $0.key, hexColor: $0.value.hex, amount: $0.value.total) }
            .sorted { $0.amount > $1.amount }

        return BudgetSummary(
            id: budget.objectID,
            budgetName: budget.name ?? "Untitled",
            periodStart: startDate,
            periodEnd: endDate,
            categoryBreakdown: categoryBreakdown,
            variableExpensesTotal: variableTotal,
            plannedExpensesPlannedTotal: plannedPlanned,
            plannedExpensesActualTotal: plannedActual,
            potentialIncomeTotal: incomeTotals.planned,
            actualIncomeTotal: incomeTotals.actual
        )
    }

    // MARK: Derived filtered/sorted
    var plannedFilteredSorted: [PlannedExpense] {
        var rows = plannedExpenses

        // Date filter (if a PlannedExpense lacks a date, include it)
        rows = rows.filter { pe in
            guard let d = pe.transactionDate else { return true }
            return d >= startDate && d <= endDate
        }

        // Search filter
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            rows = rows.filter { ($0.descriptionText ?? "").lowercased().contains(q) }
        }

        // Sort
        switch sort {
        case .titleAZ:
            rows.sort {
                ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending
            }
        case .amountLowHigh:
            rows.sort { $0.plannedAmount < $1.plannedAmount }
        case .amountHighLow:
            rows.sort { $0.plannedAmount > $1.plannedAmount }
        case .dateOldNew:
            rows.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            rows.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return rows
    }

    var unplannedFilteredSorted: [UnplannedExpense] {
        var rows = unplannedExpenses

        // Date filter (unplanned has required transactionDate)
        rows = rows.filter {
            let d = $0.transactionDate ?? .distantPast
            return d >= startDate && d <= endDate
        }

        // Search filter across description + category name
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            rows = rows.filter {
                ($0.descriptionText ?? "").lowercased().contains(q)
                || ($0.expenseCategory?.name ?? "").lowercased().contains(q)
            }
        }

        // Sort
        switch sort {
        case .titleAZ:
            rows.sort {
                ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending
            }
        case .amountLowHigh:
            rows.sort { $0.amount < $1.amount }
        case .amountHighLow:
            rows.sort { $0.amount > $1.amount }
        case .dateOldNew:
            rows.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            rows.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return rows
    }

    // MARK: Init
    init(budgetObjectID: NSManagedObjectID,
         context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.budgetObjectID = budgetObjectID
        self.context = context
    }

    // MARK: Public API

    /// Loads budget, initializes date window, and fetches rows.
    func load() async {
        if isLoadInFlight {
            shouldReloadAfterCurrentRun = true
            AppLog.viewModel.debug("BudgetDetailsViewModel.load() coalesced – load already in flight")
            return
        }

        isLoadInFlight = true
        AppLog.viewModel.debug("BudgetDetailsViewModel.load() started – current state: \(String(describing: self.loadState))")
        defer {
            isLoadInFlight = false
            if shouldReloadAfterCurrentRun {
                shouldReloadAfterCurrentRun = false
                AppLog.viewModel.debug("BudgetDetailsViewModel.load() scheduling coalesced reload")
                Task { [weak self] in
                    await self?.load()
                }
            }
        }

        if budget != nil, didInitializeDateWindow {
            await refreshRows()
            if case .failed = loadState {
                // Preserve failure state if we previously surfaced an error.
            } else {
                loadState = .loaded
                AppLog.viewModel.debug("BudgetDetailsViewModel.load() reused existing budget – transitioning to .loaded")
            }
            return
        }

        if isInitialLoadInFlight {
            AppLog.viewModel.debug("BudgetDetailsViewModel.load() exiting early – initial load already in flight")
            return
        }

        isInitialLoadInFlight = true
        defer { isInitialLoadInFlight = false }

        loadState = .loading
        AppLog.viewModel.debug("BudgetDetailsViewModel.load() awaiting persistent stores…")
        CoreDataService.shared.ensureLoaded()
        await CoreDataService.shared.waitUntilStoresLoaded()
        AppLog.viewModel.debug("BudgetDetailsViewModel.load() continuing – storesLoaded: \(CoreDataService.shared.storesLoaded)")

        // Resolve the Budget instance (use existingObject to avoid stale faults)
        let resolvedBudget: Budget?
        if let b = try? context.existingObject(with: budgetObjectID) as? Budget {
            resolvedBudget = b
        } else {
            resolvedBudget = context.object(with: budgetObjectID) as? Budget
        }

        guard let budget = resolvedBudget else {
            let message = "We couldn't load this budget. It may have been deleted or moved."
            AppLog.viewModel.error("BudgetDetailsViewModel failed to resolve budget with objectID: \(String(describing: self.budgetObjectID))")
            loadState = .failed(message: message)
            alert = BudgetDetailsAlert(kind: .error(message: message))
            return
        }

        self.budget = budget

        let defaultStart = budget.startDate ?? Month.start(of: Date())
        let defaultEnd   = budget.endDate ?? Month.end(of: Date())

        if !didInitializeDateWindow {
            startDate = defaultStart
            endDate = defaultEnd
            didInitializeDateWindow = true
        }

        await refreshRows()
        loadState = .loaded
        AppLog.viewModel.debug("BudgetDetailsViewModel.load() finished – transitioning to .loaded")
    }

    /// Re-fetches rows for current filters (date window driven on fetch).
    func refreshRows() async {
        let range = normalizedRange()
        plannedExpenses = fetchPlannedExpenses(for: budget, in: range)
        unplannedExpenses = fetchUnplannedExpenses(for: budget, in: range)

        if let totals = try? BudgetIncomeCalculator.totals(
            for: DateInterval(start: range.lowerBound, end: range.upperBound),
            context: context
        ) {
            incomeTotals = IncomeTotals(planned: totals.planned, actual: totals.actual)
        } else {
            incomeTotals = .zero
        }
        AppLog.viewModel.debug(
            "BudgetDetailsViewModel.refreshRows() updated – planned: \(self.plannedExpenses.count), unplanned: \(self.unplannedExpenses.count), incomeTotals: planned=\(self.incomeTotals.planned) actual=\(self.incomeTotals.actual)"
        )
    }

    /// Resets the date window to the budget's own period.
    func resetDateWindowToBudget() {
        guard let b = budget else { return }
        startDate = b.startDate ?? startDate
        endDate = b.endDate ?? endDate
    }

    // MARK: - Fetch helpers

    /// Planned expenses attached to this budget (optionally filtered by date).
    private func fetchPlannedExpenses(for budget: Budget?, in range: ClosedRange<Date>) -> [PlannedExpense] {
        guard let budget else { return [] }
        let req = NSFetchRequest<PlannedExpense>(entityName: "PlannedExpense")
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "budget == %@", budget),
            NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate)
        ])
        req.sortDescriptors = [
            NSSortDescriptor(key: "transactionDate", ascending: false),
            NSSortDescriptor(key: "descriptionText", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    /// Unplanned expenses that should be considered for a budget.
    /// Primary path uses UnplannedExpenseService (ANY card.budget.id == budget.id).
    /// Fallback path uses the Budget.cards relationship directly.
    private func fetchUnplannedExpenses(for budget: Budget?, in range: ClosedRange<Date>) -> [UnplannedExpense] {
        guard let budget else { return [] }
        let interval = DateInterval(start: range.lowerBound, end: range.upperBound)

        // Preferred: via service using Budget UUID (more tolerant of schema naming on Card side)
        if let bid = budget.value(forKey: "id") as? UUID {
            if let rows = try? unplannedService.fetchForBudget(bid, in: interval, sortedByDateAscending: false) {
                return rows
            }
        }

        // Fallback: via explicit cards set (works regardless of inverse name on Card)
        guard let cards = (budget.cards as? Set<Card>), !cards.isEmpty else { return [] }
        let req = NSFetchRequest<UnplannedExpense>(entityName: "UnplannedExpense")
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "card IN %@", cards),
            NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@", range.lowerBound as NSDate, range.upperBound as NSDate)
        ])
        req.sortDescriptors = [
            NSSortDescriptor(key: "transactionDate", ascending: false),
            NSSortDescriptor(key: "descriptionText", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    private func normalizedRange() -> ClosedRange<Date> {
        let lower = min(startDate, endDate)
        let upper = max(startDate, endDate)
        return lower...upper
    }

    var placeholderText: String {
        switch loadState {
        case .failed(let message):
            return message
        case .idle, .loading:
            return "Loading…"
        case .loaded:
            return "Budget unavailable."
        }
    }
}
