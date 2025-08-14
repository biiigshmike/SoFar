//
//  HomeViewModel.swift
//  SoFar
//
//  Drives the home screen: loads budgets for the selected month,
//  computes per-budget summaries (planned/actual income & expenses,
//  variable spend by category), and exposes filtered results for the grid.
//  NOTE: Income is fetched by DATE RANGE only; there is no Budget↔Income link.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - BudgetLoadState
/// Represents the loading state for budgets to prevent UI flickering
enum BudgetLoadState: Equatable {
    /// The view has not started loading yet.
    case initial
    /// Loading is in progress (and has taken >200ms).
    case loading
    /// Loading is complete, and there are no items.
    case empty
    /// Loading is complete, and there are items to display.
    case loaded([BudgetSummary])
}

// MARK: - BudgetSummary (View Model DTO)
/// Immutable data passed to the card view for rendering.
struct BudgetSummary: Identifiable, Equatable {

    // MARK: Identity
    /// Stable identifier derived from the managed object's ID.
    let id: NSManagedObjectID

    // MARK: Budget Basics
    let budgetName: String
    let periodStart: Date
    let periodEnd: Date

    // MARK: Variable Spend (Unplanned) by Category
    struct CategorySpending: Identifiable, Equatable {
        let id = UUID()
        let categoryName: String
        let hexColor: String?
        let amount: Double
    }
    let categoryBreakdown: [CategorySpending]
    let variableExpensesTotal: Double

    // MARK: Planned Expenses (line items attached to budget)
    let plannedExpensesPlannedTotal: Double
    let plannedExpensesActualTotal: Double

    // MARK: Income (date-based; no relationship)
    let plannedIncomeTotal: Double
    let actualIncomeTotal: Double

    // MARK: Savings
    var plannedSavingsTotal: Double { plannedIncomeTotal - plannedExpensesPlannedTotal }
    var actualSavingsTotal: Double {
        actualIncomeTotal - (plannedExpensesActualTotal + variableExpensesTotal)
    }

    // MARK: Convenience
    var periodString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return "\(f.string(from: periodStart)) through \(f.string(from: periodEnd))"
    }
}

// MARK: - Month (Helper)
/// Utilities for deriving month ranges.
enum Month {
    // MARK: start(of:)
    static func start(of date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    // MARK: end(of:)
    static func end(of date: Date) -> Date {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: date)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return date
        }
        // Set to end of day for inclusive comparisons
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
    }

    // MARK: range(for:)
    static func range(for date: Date) -> (start: Date, end: Date) {
        (start(of: date), end(of: date))
    }
}

// MARK: - HomeViewModel
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: Published State
    @Published var selectedMonth: Date = Month.start(of: Date()) {
        didSet { Task { await refresh() } }
    }
    @Published var searchQuery: String = ""
    @Published private(set) var state: BudgetLoadState = .initial

    // MARK: Dependencies
    private let context: NSManagedObjectContext
    private var hasStarted = false

    // MARK: init()
    /// - Parameter context: The Core Data context to use (defaults to main viewContext).
    init(context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.context = context
    }

    // MARK: startIfNeeded()
    /// Starts loading budgets exactly once.
    /// This uses a delayed transition to the `.loading` state to prevent
    /// the loading indicator from flashing on screen for fast loads.
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        // After a 200ms delay, if we are still in the `initial` state,
        // we transition to the `loading` state.
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if case .initial = self.state {
                self.state = .loading
            }
        }

        // Immediately start the actual data fetch.
        Task { await refresh() }
    }

    // MARK: refresh()
    /// Loads budgets that overlap the selected month and computes summaries.
    /// - Important: This uses each budget's own start/end when computing totals.
    func refresh() async {
        let (start, end) = Month.range(for: selectedMonth)

        // Fetch budgets overlapping month
        let budgets: [Budget] = fetchBudgets(overlapping: start...end)

        // Build summaries
        let summaries: [BudgetSummary] = budgets.compactMap { (budget: Budget) -> BudgetSummary? in
            guard let startDate = budget.startDate, let endDate = budget.endDate else { return nil }
            return buildSummary(for: budget, periodStart: startDate, periodEnd: endDate)
        }
        .sorted { (first: BudgetSummary, second: BudgetSummary) -> Bool in
            (first.periodStart, first.budgetName) < (second.periodStart, second.budgetName)
        }

        if summaries.isEmpty {
            self.state = .empty
        } else {
            self.state = .loaded(summaries)
        }
    }

    // MARK: adjustSelectedMonth(byMonths:)
    /// Moves the selected month forward/backward.
    /// - Parameter delta: Positive to go forward, negative to go backward.
    func adjustSelectedMonth(byMonths delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonth) {
            selectedMonth = Month.start(of: newDate)
        }
    }

    // MARK: Derived Results
    /// Filters budgets by budget name (case-insensitive). Empty query returns all.
    var filteredBudgets: [BudgetSummary] {
        let budgets: [BudgetSummary]
        switch state {
        case .loaded(let items):
            budgets = items
        default:
            budgets = []
        }
        
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return budgets
        }
        let query = searchQuery.lowercased()
        return budgets.filter { $0.budgetName.lowercased().contains(query) }
    }

    // MARK: - Private: Fetching

    // MARK: fetchBudgets(overlapping:)
    /// Returns budgets that overlap the given date range.
    /// - Parameter month: The month window to match against budget start/end.
    private func fetchBudgets(overlapping month: ClosedRange<Date>) -> [Budget] {
        let req = NSFetchRequest<Budget>(entityName: "Budget")
        let start = month.lowerBound
        let end = month.upperBound

        // Overlap predicate: (startDate <= end) AND (endDate >= start)
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "startDate <= %@", end as NSDate),
            NSPredicate(format: "endDate >= %@", start as NSDate)
        ])
        req.sortDescriptors = [
            NSSortDescriptor(key: "startDate", ascending: true),
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        do { return try context.fetch(req) } catch { return [] }
    }

    // MARK: buildSummary(for:periodStart:periodEnd:)
    /// Computes totals and category breakdown for a single budget.
    /// - Parameters:
    ///   - budget: The budget record.
    ///   - periodStart: Inclusive start date for calculations.
    ///   - periodEnd: Inclusive end date for calculations.
    /// - Returns: A `BudgetSummary` for display.
    private func buildSummary(for budget: Budget, periodStart: Date, periodEnd: Date) -> BudgetSummary {
        // MARK: Planned Expenses (attached to budget)
        let plannedFetch = NSFetchRequest<PlannedExpense>(entityName: "PlannedExpense")
        plannedFetch.predicate = NSPredicate(format: "budget == %@", budget)
        let plannedExpenses: [PlannedExpense] = (try? context.fetch(plannedFetch)) ?? []

        let plannedExpensesPlannedTotal = plannedExpenses.reduce(0.0) { $0 + $1.plannedAmount }
        let plannedExpensesActualTotal  = plannedExpenses.reduce(0.0) { $0 + $1.actualAmount }

        // MARK: Income (DATE-ONLY; no relationship)
        // Income events exist globally on the calendar; we include any whose date falls within the budget window.
        let incomeFetch = NSFetchRequest<Income>(entityName: "Income")
        incomeFetch.predicate = NSPredicate(format: "date >= %@ AND date <= %@", periodStart as NSDate, periodEnd as NSDate)
        let incomes: [Income] = (try? context.fetch(incomeFetch)) ?? []
        let plannedIncomeTotal = incomes.filter { $0.isPlanned }.reduce(0.0) { $0 + $1.amount }
        let actualIncomeTotal  = incomes.filter { !$0.isPlanned }.reduce(0.0) { $0 + $1.amount }

        // MARK: Variable (Unplanned) Expenses (from tracked cards, within window)
        let cards = (budget.cards as? Set<Card>) ?? []
        var categoryMap: [String: (hex: String?, total: Double)] = [:]
        var variableTotal: Double = 0

        if !cards.isEmpty {
            let unplannedReq = NSFetchRequest<UnplannedExpense>(entityName: "UnplannedExpense")
            unplannedReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "card IN %@", cards),
                NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@", periodStart as NSDate, periodEnd as NSDate)
            ])
            let unplanned: [UnplannedExpense] = (try? context.fetch(unplannedReq)) ?? []
            for e in unplanned {
                let amt = e.amount
                variableTotal += amt

                let catName = e.expenseCategory?.name ?? "Uncategorized"
                // Your model uses `ExpenseCategory.color` (hex string).
                let hex = e.expenseCategory?.color
                let existing = categoryMap[catName] ?? (hex: hex, total: 0)
                categoryMap[catName] = (hex: hex ?? existing.hex, total: existing.total + amt)
            }
        }

        let categoryBreakdown: [BudgetSummary.CategorySpending] = categoryMap
            .map { BudgetSummary.CategorySpending(categoryName: $0.key, hexColor: $0.value.hex, amount: $0.value.total) }
            .sorted(by: { $0.amount > $1.amount })

        return BudgetSummary(
            id: budget.objectID,
            budgetName: budget.name ?? "Untitled",
            periodStart: periodStart,
            periodEnd: periodEnd,
            categoryBreakdown: categoryBreakdown,
            variableExpensesTotal: variableTotal,
            plannedExpensesPlannedTotal: plannedExpensesPlannedTotal,
            plannedExpensesActualTotal: plannedExpensesActualTotal,
            plannedIncomeTotal: plannedIncomeTotal,
            actualIncomeTotal: actualIncomeTotal
        )
    }
}