//
//  HomeViewModel.swift
//  SoFar
//
//  Drives the home screen: loads budgets for the selected month and
//  computes per-budget summaries (planned/actual income & expenses and
//  variable spend by category). NOTE: Income is fetched by DATE RANGE
//  only; there is no Budget↔Income link.
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

// MARK: - HomeViewAlert
/// Alert types surfaced by the home screen.
struct HomeViewAlert: Identifiable {
    enum Kind {
        case error(message: String)
        case confirmDelete(budgetID: NSManagedObjectID)
    }
    let id = UUID()
    let kind: Kind
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
    /// Total income expected for the period (e.g. paychecks not yet received).
    let potentialIncomeTotal: Double
    /// Income actually received so far in the period.
    let actualIncomeTotal: Double

    // MARK: Savings
    /// Savings you could have if all potential income arrives and only planned expenses occur.
    var potentialSavingsTotal: Double { potentialIncomeTotal - plannedExpensesPlannedTotal }
    /// Savings based on actual income received minus both actual planned expenses and variable expenses.
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
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue)
    private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue {
        didSet {
            selectedDate = period.start(of: Date())
            Task { await refresh() }
        }
    }

    private var period: BudgetPeriod {
        BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly
    }

    @Published var selectedDate: Date = BudgetPeriod.monthly.start(of: Date()) {
        didSet { Task { await refresh() } }
    }
    @Published private(set) var state: BudgetLoadState = .initial
    @Published var alert: HomeViewAlert?

    // MARK: Dependencies
    private let context: NSManagedObjectContext
    private let budgetService = BudgetService()
    private var hasStarted = false

    // MARK: init()
    /// - Parameter context: The Core Data context to use (defaults to main viewContext).
    init(context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.context = context
        self.selectedDate = period.start(of: Date())
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
    /// Loads budgets that overlap the selected period and computes summaries.
    /// - Important: This uses each budget's own start/end when computing totals.
    func refresh() async {
        let (start, end) = period.range(containing: selectedDate)

        // Fetch budgets overlapping period and matching the selected budget period
        let budgets: [Budget] = fetchBudgets(overlapping: start...end).filter { budget in
            guard let s = budget.startDate, let e = budget.endDate else { return false }
            return period.matches(startDate: s, endDate: e)
        }

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

    // MARK: updateBudgetPeriod(to:)
    /// Updates the budget period preference and triggers a refresh.
    /// - Parameter newPeriod: The newly selected budget period.
    func updateBudgetPeriod(to newPeriod: BudgetPeriod) {
        budgetPeriodRawValue = newPeriod.rawValue
    }

    // MARK: adjustSelectedPeriod(by:)
    /// Moves the selected period forward/backward.
    /// - Parameter delta: Positive to go forward, negative to go backward.
    func adjustSelectedPeriod(by delta: Int) {
        selectedDate = period.advance(selectedDate, by: delta)
    }

    // MARK: Deletion
    /// Requests deletion for the provided budget object ID, honoring the user's confirm setting.
    func requestDelete(budgetID: NSManagedObjectID) {
        let confirm = UserDefaults.standard.bool(forKey: AppSettingsKeys.confirmBeforeDelete.rawValue)
        if confirm {
            alert = HomeViewAlert(kind: .confirmDelete(budgetID: budgetID))
        } else {
            Task { await confirmDelete(budgetID: budgetID) }
        }
    }

    /// Permanently deletes a budget and refreshes state.
    func confirmDelete(budgetID: NSManagedObjectID) async {
        do {
            if let budget = try context.existingObject(with: budgetID) as? Budget {
                try budgetService.deleteBudget(budget)
                await refresh()
            }
        } catch {
            alert = HomeViewAlert(kind: .error(message: error.localizedDescription))
        }
    }

    // MARK: - Private: Fetching

    // MARK: fetchBudgets(overlapping:)
    /// Returns budgets that overlap the given date range.
    /// - Parameter range: The date window to match against budget start/end.
    private func fetchBudgets(overlapping range: ClosedRange<Date>) -> [Budget] {
        let req = NSFetchRequest<Budget>(entityName: "Budget")
        let start = range.lowerBound
        let end = range.upperBound

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
        let potentialIncomeTotal = incomes.filter { $0.isPlanned }.reduce(0.0) { $0 + $1.amount }
        let actualIncomeTotal    = incomes.filter { !$0.isPlanned }.reduce(0.0) { $0 + $1.amount }

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
            potentialIncomeTotal: potentialIncomeTotal,
            actualIncomeTotal: actualIncomeTotal
        )
    }
}