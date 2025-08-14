//
//  BudgetCardView.swift
//  SoFar
//
//  Renders one budget summary “card” with:
//  - Title + period
//  - Variable expenses by category (colored dots & right-aligned amounts)
//  - Metrics grid: planned/actual expenses & incomes, then savings
//

import SwiftUI
import CoreData

// MARK: - BudgetCardView
struct BudgetCardView: View {

    // MARK: Inputs
    let summary: BudgetSummary

    // MARK: Environment
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Local State (computed income overrides)
    /// When computed, these override the incoming summary’s income values.
    @State private var plannedIncomeOverride: Double? = nil
    @State private var actualIncomeOverride: Double? = nil

    // MARK: Layout
    private let sidePadding: CGFloat = DS.Spacing.l
    private let innerSpacing: CGFloat = DS.Spacing.m

    // MARK: Currency
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: innerSpacing) {

            // MARK: Header
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.budgetName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(UBTypography.cardTitleStatic)
                    .ub_cardTitleShadow()

                Text(summary.periodString)
                    .foregroundStyle(.secondary)
            }

            // MARK: Variable Expenses by Category
            if !summary.categoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.categoryBreakdown.prefix(6)) { cat in
                        HStack {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: cat.hexColor) ?? .accentColor.opacity(0.7))
                                    .frame(width: 12, height: 12)
                                Text(cat.categoryName)
                            }

                            Spacer(minLength: 8)

                            Text(cat.amount, format: .currency(code: currencyCode))
                                .font(.callout.weight(.semibold))
                        }
                    }
                }
                .padding(.top, 6)
            }

            // MARK: Metrics Grid
            VStack(spacing: 12) {
                Grid(horizontalSpacing: 20, verticalSpacing: 10) {

                    GridRow {
                        Metric(title: "PLANNED EXPENSES",
                               value: summary.plannedExpensesPlannedTotal,
                               tint: .primary)
                        Metric(title: "VARIABLE EXPENSES",
                               value: summary.variableExpensesTotal,
                               tint: .primary)
                    }

                    GridRow {
                        Metric(title: "PLANNED INCOME",
                               value: plannedIncomeOverride ?? summary.plannedIncomeTotal,
                               tint: DS.Colors.plannedIncome)
                        Metric(title: "ACTUAL INCOME",
                               value: actualIncomeOverride ?? summary.actualIncomeTotal,
                               tint: DS.Colors.actualIncome)
                    }

                    GridRow {
                        // NOTE: Savings currently come from your summary object.
                        // If you want savings to reflect the newly computed incomes,
                        // we can rewire this after you confirm your exact formula.
                        Metric(title: "PLANNED SAVINGS",
                               value: summary.plannedSavingsTotal,
                               tint: DS.Colors.savingsGood)
                        Metric(title: "ACTUAL SAVINGS",
                               value: summary.actualSavingsTotal,
                               tint: summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad)
                    }
                }
            }
            .padding(.top, DS.Spacing.s)
        }
        .padding(sidePadding)
        .cardBackground()
        .accessibilityElement(children: .contain)
        .onAppear { computeIncomeOverridesIfPossible() } // MARK: Trigger computation on appear
    }

    // MARK: Metric (Subview)
    /// Displays a label and a centered, bold currency amount tinted by purpose.
    /// - Parameters:
    ///   - title: Uppercased label displayed above the value.
    ///   - value: Currency number to display.
    ///   - tint: Foreground color for the value.
    private func Metric(title: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Center the numeric line and make it the visual anchor for the row
            Text(value, format: .currency(code: currencyCode))
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Income Computation
    /// Fetches the Budget by `summary.id`, builds the DateInterval, and computes planned/actual income.
    /// Safe no-op if the budget cannot be fetched or the dates are missing.
    private func computeIncomeOverridesIfPossible() {
        do {
            guard let budget = try viewContext.existingObject(with: summary.id) as? Budget else { return }

            let start = budget.startDate ?? .distantPast
            let end   = budget.endDate   ?? .distantFuture
            let window = DateInterval(start: start, end: end)

            let totals = try BudgetIncomeCalculator.totals(for: window, context: viewContext)
            plannedIncomeOverride = totals.planned
            actualIncomeOverride  = totals.actual
        } catch {
            // If anything fails, we keep using the incoming summary values.
            // You can log this if desired:
            // Logger.shared.warn("Income calc failed: \(error.localizedDescription)")
        }
    }
}
