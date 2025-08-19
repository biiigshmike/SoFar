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

    // MARK: Summary
    /// Computed summary of totals used by the header.
    var summary: BudgetSummary? {
        guard let budget else { return nil }

        let plannedPlanned = plannedExpenses.reduce(0) { $0 + $1.plannedAmount }
        let plannedActual  = plannedExpenses.reduce(0) { $0 + $1.actualAmount }

        var categoryMap: [String: (hex: String?, total: Double)] = [:]
        var variableTotal: Double = 0
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

        let incomeTotals = (try? BudgetIncomeCalculator.totals(for: DateInterval(start: startDate, end: endDate), context: context)) ?? (planned: 0, actual: 0)

        return BudgetSummary(
            id: budget.objectID,
            budgetName: budget.name ?? "Untitled",
            periodStart: startDate,
            periodEnd: endDate,
            categoryBreakdown: categoryBreakdown,
            variableExpensesTotal: variableTotal,
            plannedExpensesPlannedTotal: plannedPlanned,
            plannedExpensesActualTotal: plannedActual,
            plannedIncomeTotal: incomeTotals.planned,
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
        CoreDataService.shared.ensureLoaded()

        // Resolve the Budget instance (use existingObject to avoid stale faults)
        if let b = try? context.existingObject(with: budgetObjectID) as? Budget {
            budget = b
        } else {
            budget = context.object(with: budgetObjectID) as? Budget
        }

        let defaultStart = budget?.startDate ?? Month.start(of: Date())
        let defaultEnd   = budget?.endDate ?? Month.end(of: Date())

        if !didInitializeDateWindow {
            startDate = defaultStart
            endDate = defaultEnd
            didInitializeDateWindow = true
        }

        await refreshRows()
    }

    /// Re-fetches rows for current filters (date window driven on fetch).
    func refreshRows() async {
        plannedExpenses = fetchPlannedExpenses(for: budget, in: startDate...endDate)
        unplannedExpenses = fetchUnplannedExpenses(for: budget, in: startDate...endDate)
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
}
