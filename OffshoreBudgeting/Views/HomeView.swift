//
//  HomeView.swift
//  SoFar
//
//  Displays month header and, when a budget exists for the selected month,
//  shows the full BudgetDetailsView inline. Otherwise an empty state encourages
//  creating a budget.
//
//  Scroll behaviour:
//  - RootTabPageScaffold owns the primary scroll host so large titles collapse.
//  - RootTabListHostingContainer constrains BudgetDetailsView to the available
//    viewport height, letting its Lists own vertical scrolling without nesting.
//  - The empty state uses a VStack sized to the available height so the
//    scaffold’s scroll view can manage reachability on compact devices.
//

import SwiftUI
import UIKit
import CoreData
import Foundation
import Combine

// MARK: - HomeView
struct HomeView: View {

    // MARK: State & ViewModel
    @StateObject private var vm = HomeViewModel()
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue) private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue
    private var budgetPeriod: BudgetPeriod { BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly }
    @State private var selectedSegment: BudgetDetailsViewModel.Segment = .planned
    @State private var homeSort: BudgetDetailsViewModel.SortOption = .dateNewOld

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false
    @State private var editingBudget: BudgetSummary?
    // Direct add flows when no budget is active
    @State private var isPresentingAddPlannedFromHome: Bool = false
    @State private var isPresentingAddVariableFromHome: Bool = false
    // Manage sheets
    @State private var isPresentingManageCards: Bool = false
    @State private var isPresentingManagePresets: Bool = false

    // MARK: Body
    var body: some View {
        // Sticky header is managed by RootTabPageScaffold.
        // - Empty states leverage the scaffold's scroll view for reachability.
        // - Loaded budgets run through RootTabListHostingContainer so Lists keep
        //   control of vertical scrolling without nested scroll views.
        RootTabPageScaffold(
            scrollBehavior: .auto,
            spacing: DS.Spacing.s
        ) {
            headerSection
        } content: { proxy in
            contentContainer(proxy: proxy)
                .rootTabContentPadding(
                    proxy,
                    horizontal: 0,
                    includeSafeArea: false,
                    tabBarGutter: proxy.compactAwareTabBarGutter
                )
        }
        .ub_tabNavigationTitle("Home")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                calendarToolbarMenu()

                if let summary = primarySummary {
                    addExpenseToolbarMenu(for: summary.id)
                    optionsToolbarMenu(summary: summary)
                } else {
                    addExpenseToolbarMenu()
                    optionsToolbarMenu()
                }
            }
        }
        .task {
            CoreDataService.shared.ensureLoaded()
            vm.startIfNeeded()
        }
        // Temporarily disable automatic refresh on every Core Data save to
        // prevent re-entrant view reconstruction and load() loops. Explicit
        // onSaved callbacks already trigger refreshes where it matters.
        .ub_onChange(of: budgetPeriodRawValue) { newValue in
            let newPeriod = BudgetPeriod(rawValue: newValue) ?? .monthly
            vm.updateBudgetPeriod(to: newPeriod)
        }

        // MARK: ADD SHEET — present new budget UI for the selected period
        .sheet(isPresented: $isPresentingAddBudget, content: makeAddBudgetView)
        .sheet(item: $editingBudget, content: makeEditBudgetView)
        .sheet(isPresented: $isPresentingAddPlannedFromHome) {
            AddPlannedExpenseView(
                preselectedBudgetID: nil,
                defaultSaveAsGlobalPreset: false,
                showAssignBudgetToggle: true,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .sheet(isPresented: $isPresentingAddVariableFromHome) {
            AddUnplannedExpenseView(
                allowedCardIDs: nil,
                initialDate: vm.selectedDate,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .sheet(isPresented: $isPresentingManageCards) {
            if let budgetID = primarySummary?.id,
               let budget = try? CoreDataService.shared.viewContext.existingObject(with: budgetID) as? Budget {
                ManageBudgetCardsSheet(budget: budget) { Task { await vm.refresh() } }
                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            } else {
                Text("No budget selected")
            }
        }
        .sheet(isPresented: $isPresentingManagePresets) {
            PresetsView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .alert(item: $vm.alert, content: alert(for:))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: headerSectionSpacing) {
            if let summary = primarySummary {
                HomeHeaderPrimarySummaryView(
                    summary: summary,
                    displayTitle: periodHeaderTitle,
                    displayDetail: periodRangeDetail
                )
                .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
            } else {
                // Sticky header fallback when no budget is loaded for the period.
                HomeHeaderFallbackTitleView(
                    displayTitle: periodHeaderTitle,
                    displayDetail: periodRangeDetail
                )
                .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)

                // Show the income/savings grid with zero values so the header
                // remains informative even before a budget exists for this
                // period. This mirrors the look when a budget is present.
                HomeIncomeSavingsZeroSummaryView()
                    .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)

                // Keep the dynamic header concise; segment control appears in content below.
            }
        }
    }

    // MARK: Toolbar Actions
    private func calendarToolbarMenu() -> some View {
        Menu {
            ForEach(BudgetPeriod.selectableCases) { period in
                Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
            }
        } label: {
            RootHeaderControlIcon(systemImage: "calendar")
                .accessibilityLabel(budgetPeriod.displayName)
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel(budgetPeriod.displayName)
    }

    private func addExpenseToolbarMenu() -> some View {
        Menu {
            Button("Add Planned Expense") { isPresentingAddPlannedFromHome = true }
            Button("Add Variable Expense") { isPresentingAddVariableFromHome = true }
        } label: {
            RootHeaderControlIcon(systemImage: "plus")
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel("Add Expense")
    }

    private func addExpenseToolbarMenu(for budgetID: NSManagedObjectID) -> some View {
        Menu {
            Button("Add Planned Expense") {
                triggerAddExpense(.budgetDetailsRequestAddPlannedExpense, budgetID: budgetID)
            }
            Button("Add Variable Expense") {
                triggerAddExpense(.budgetDetailsRequestAddVariableExpense, budgetID: budgetID)
            }
        } label: {
            RootHeaderControlIcon(systemImage: "plus")
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel("Add Expense")
    }

    private func optionsToolbarMenu() -> some View {
        Menu {
            Button {
                isPresentingAddBudget = true
            } label: {
                Label("Create Budget", systemImage: "plus")
            }
        } label: {
            RootHeaderControlIcon(systemImage: "ellipsis", symbolVariants: SymbolVariants.none)
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel("Budget Options")
    }

    private func optionsToolbarMenu(summary: BudgetSummary) -> some View {
        Menu {
            Button { isPresentingManageCards = true } label: { Label("Manage Cards", systemImage: "creditcard") }
            Button { isPresentingManagePresets = true } label: { Label("Manage Presets", systemImage: "list.bullet.rectangle") }
            Button {
                editingBudget = summary
            } label: {
                Label("Edit Budget", systemImage: "pencil")
            }
            Button(role: .destructive) {
                vm.requestDelete(budgetID: summary.id)
            } label: {
                Label("Delete Budget", systemImage: "trash")
            }
        } label: {
            RootHeaderControlIcon(systemImage: "ellipsis", symbolVariants: SymbolVariants.none)
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel("Budget Actions")
    }

    // MARK: Sheets & Alerts
    @ViewBuilder
    private func makeAddBudgetView() -> some View {
        let (start, end) = budgetPeriod.range(containing: vm.selectedDate)
        if #available(iOS 16.0, *) {
            AddBudgetView(
                initialStartDate: start,
                initialEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
        } else {
            AddBudgetView(
                initialStartDate: start,
                initialEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    @ViewBuilder
    private func makeEditBudgetView(summary: BudgetSummary) -> some View {
        if #available(iOS 16.0, *) {
            AddBudgetView(
                editingBudgetObjectID: summary.id,
                fallbackStartDate: summary.periodStart,
                fallbackEndDate: summary.periodEnd,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
        } else {
            AddBudgetView(
                editingBudgetObjectID: summary.id,
                fallbackStartDate: summary.periodStart,
                fallbackEndDate: summary.periodEnd,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    private func alert(for alert: HomeViewAlert) -> Alert {
        switch alert.kind {
        case .error(let message):
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        case .confirmDelete(let id):
            return Alert(
                title: Text("Delete Budget?"),
                message: Text("This action cannot be undone."),
                primaryButton: .destructive(Text("Delete"), action: { Task { await vm.confirmDelete(budgetID: id) } }),
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: Content Container
    private func contentContainer(proxy: RootTabPageProxy) -> some View {
        Group {
            switch vm.state {
            case .initial:
                // Initially nothing is shown to prevent blinking
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            case .empty:
                emptyPeriodContent(proxy: proxy)

            case .loaded(let summaries):
                if let first = summaries.first {
                    loadedBudgetContent(for: first, proxy: proxy)
                } else {
                    emptyPeriodContent(proxy: proxy)
                }
            }
        }
    }

    // MARK: Empty Period Content (replaces generic empty state)
    @ViewBuilder
    private func emptyPeriodContent(proxy: RootTabPageProxy) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // Period navigation in content (original position)
            periodNavigationControl()
                .frame(maxWidth: .infinity, alignment: .leading)

            // Section header + running total for the current segment
            HomeSegmentTotalsRowView(segment: selectedSegment, total: 0)

            // Segment control in content
            GlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s) {
                Picker("", selection: $selectedSegment) {
                    Text("Planned Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.planned)
                    Text("Variable Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.variable)
                }
                .pickerStyle(.segmented)
                .equalWidthSegments()
                .frame(maxWidth: .infinity)
                .modifier(UBSegmentedControlStyleModifier())
            }

            // Filter bar (sort options)
            GlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s, alignment: .center) {
                Picker("Sort", selection: $homeSort) {
                    Text("A–Z").segmentedFill().tag(BudgetDetailsViewModel.SortOption.titleAZ)
                    Text("$↓").segmentedFill().tag(BudgetDetailsViewModel.SortOption.amountLowHigh)
                    Text("$↑").segmentedFill().tag(BudgetDetailsViewModel.SortOption.amountHighLow)
                    Text("Date ↑").segmentedFill().tag(BudgetDetailsViewModel.SortOption.dateOldNew)
                    Text("Date ↓").segmentedFill().tag(BudgetDetailsViewModel.SortOption.dateNewOld)
                }
                .pickerStyle(.segmented)
                .equalWidthSegments()
                .frame(maxWidth: .infinity)
                .modifier(UBSegmentedControlStyleModifier())
            }

            // Always-offer Add button when no budget exists so users can
            // quickly create an expense for this period.
            GlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s, alignment: .center) {
                Button(action: addExpenseCTAAction) {
                    Label(addExpenseCTATitle, systemImage: "plus")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("emptyPeriodAddExpenseCTA")
            }

            // Segment-specific guidance — centered consistently across platforms
            Text(emptyShellMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.l)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: proxy.availableHeightBelowHeader, alignment: .top)
    }

    @ViewBuilder
    private func loadedBudgetContent(for summary: BudgetSummary, proxy: RootTabPageProxy) -> some View {
        let baseHeight = proxy.availableHeightBelowHeader
        let fallbackHeight = proxy.availableHeight - proxy.headerHeight
        let resolvedHeight = max(baseHeight > 0 ? baseHeight : fallbackHeight, 1)

        RootTabListHostingContainer(height: resolvedHeight) {
            BudgetDetailsView(
                budgetObjectID: summary.id,
                periodNavigation: .init(
                    title: title(for: vm.selectedDate),
                    onAdjust: { delta in vm.adjustSelectedPeriod(by: delta) }
                ),
                displaysBudgetTitle: false,
                headerTopPadding: DS.Spacing.xs,
                showsIncomeSavingsGrid: false,
                onSegmentChange: { newSegment in
                    self.selectedSegment = newSegment
                }
            )
            .id(summary.id)
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }


    private var headerSectionSpacing: CGFloat { DS.Spacing.xs / 2 }

    private func periodNavigationControl() -> PeriodNavigationControl {
        PeriodNavigationControl(
            title: title(for: vm.selectedDate),
            onPrevious: { vm.adjustSelectedPeriod(by: -1) },
            onNext: { vm.adjustSelectedPeriod(by: +1) }
        )
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        budgetPeriod.title(for: date)
    }

    // Period-driven header title, e.g. "September 2025 Budget" or
    // "Sep 1 – Sep 7, 2025 Budget" when viewing Weekly, etc.
    private var periodHeaderTitle: String {
        "\(title(for: vm.selectedDate)) Budget"
    }

    private var periodRangeDetail: String {
        let (start, end) = budgetPeriod.range(containing: vm.selectedDate)
        let f = DateFormatter()
        f.dateStyle = .medium
        return "\(f.string(from: start)) through \(f.string(from: end))"
    }

    private var primarySummary: BudgetSummary? {
        if case .loaded(let summaries) = vm.state {
            return summaries.first
        }
        return nil
    }

    private var emptyShellMessage: String {
        switch selectedSegment {
        case .planned:
            return "No planned expenses in this period."
        case .variable:
            return "No variable expenses in this period."
        }
    }

    // MARK: Empty-period CTA helpers
    private var addExpenseCTATitle: String {
        selectedSegment == .planned ? "Add Planned Expense" : "Add Variable Expense"
    }

    private func addExpenseCTAAction() {
        if selectedSegment == .planned {
            isPresentingAddPlannedFromHome = true
        } else {
            isPresentingAddVariableFromHome = true
        }
    }

    private func triggerAddExpense(_ notificationName: Notification.Name, budgetID: NSManagedObjectID) {
        NotificationCenter.default.post(name: notificationName, object: budgetID)
    }
}

// MARK: - RootTab Independent List Container
/// Bridges RootTabPageScaffold with child views that manage their own scrolling
/// (e.g., List) by constraining them to the available viewport height.
private struct RootTabListHostingContainer<Content: View>: View {
    private let height: CGFloat
    private let content: Content

    init(height: CGFloat, @ViewBuilder content: () -> Content) {
        self.height = max(height, 1)
        self.content = content()
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .overlay(alignment: .top) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .frame(height: height, alignment: .top)
            }
    }
}

// MARK: - Home Header Primary Summary
private struct HomeHeaderPrimarySummaryView: View {
    let summary: BudgetSummary
    let displayTitle: String
    let displayDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            budgetTitleView
            incomeSummaryView
        }
    }

    private var budgetTitleView: some View {
        VStack(alignment: .leading, spacing: HomeHeaderPrimarySummaryStyle.verticalSpacing) {
            Text(displayTitle)
                .font(HomeHeaderPrimarySummaryStyle.titleFont)
                .lineLimit(HomeHeaderPrimarySummaryStyle.titleLineLimit)
                .minimumScaleFactor(HomeHeaderPrimarySummaryStyle.titleMinimumScaleFactor)

            Text(displayDetail)
                .font(HomeHeaderPrimarySummaryStyle.subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(HomeHeaderPrimarySummaryStyle.subtitleLineLimit)
                .minimumScaleFactor(HomeHeaderPrimarySummaryStyle.subtitleMinimumScaleFactor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var incomeSummaryView: some View {
        BudgetIncomeSavingsSummaryView(summary: summary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum HomeHeaderPrimarySummaryStyle {
    static let verticalSpacing: CGFloat = DS.Spacing.xs / 2
    static let titleFont: Font = .largeTitle.bold()
    static let titleLineLimit: Int = 2
    static let titleMinimumScaleFactor: CGFloat = 0.75
    static let subtitleFont: Font = .callout
    static let subtitleLineLimit: Int = 1
    static let subtitleMinimumScaleFactor: CGFloat = 0.85
}

// MARK: - Fallback header when no budget exists
private struct HomeHeaderFallbackTitleView: View {
    let displayTitle: String
    let displayDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: HomeHeaderPrimarySummaryStyle.verticalSpacing) {
            Text(displayTitle)
                .font(HomeHeaderPrimarySummaryStyle.titleFont)
                .lineLimit(HomeHeaderPrimarySummaryStyle.titleLineLimit)
                .minimumScaleFactor(HomeHeaderPrimarySummaryStyle.titleMinimumScaleFactor)

            Text(displayDetail)
                .font(HomeHeaderPrimarySummaryStyle.subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(HomeHeaderPrimarySummaryStyle.subtitleLineLimit)
                .minimumScaleFactor(HomeHeaderPrimarySummaryStyle.subtitleMinimumScaleFactor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Zero summary grid for empty periods
private struct HomeIncomeSavingsZeroSummaryView: View {
    var body: some View {
        Group {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                Grid(horizontalSpacing: DS.Spacing.m, verticalSpacing: HomeIncomeSavingsMetrics.rowSpacing) {
                    headerRow("POTENTIAL INCOME", "POTENTIAL SAVINGS")
                    valuesRow(0, DS.Colors.plannedIncome, 0, DS.Colors.savingsGood)
                    headerRow("ACTUAL INCOME", "ACTUAL SAVINGS")
                    valuesRow(0, DS.Colors.actualIncome, 0, DS.Colors.savingsGood)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    VStack(alignment: .leading, spacing: HomeIncomeSavingsMetrics.rowSpacing) {
                        VStack(alignment: .leading) {
                            header("POTENTIAL INCOME")
                            value(0, DS.Colors.plannedIncome)
                        }
                        VStack(alignment: .leading) {
                            header("ACTUAL INCOME")
                            value(0, DS.Colors.actualIncome)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: HomeIncomeSavingsMetrics.rowSpacing) {
                        VStack(alignment: .trailing) {
                            header("POTENTIAL SAVINGS")
                            value(0, DS.Colors.savingsGood)
                        }
                        VStack(alignment: .trailing) {
                            header("ACTUAL SAVINGS")
                            value(0, DS.Colors.savingsGood)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func headerRow(_ left: String, _ right: String) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { header(left) }
            trailingGridCell { header(right) }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func valuesRow(_ leftValue: Double, _ leftColor: Color, _ rightValue: Double, _ rightColor: Color) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { value(leftValue, leftColor) }
            trailingGridCell { value(rightValue, rightColor) }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func leadingGridCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) { content(); Spacer(minLength: 0) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func trailingGridCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) { Spacer(minLength: 0); content().multilineTextAlignment(.trailing) }
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func header(_ title: String) -> some View {
        Text(title)
            .font(HomeIncomeSavingsMetrics.labelFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private func value(_ amount: Double, _ color: Color) -> some View {
        Text(formatCurrency(amount))
            .font(HomeIncomeSavingsMetrics.valueFont)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func formatCurrency(_ amount: Double) -> String {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            let code: String
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                code = Locale.current.currency?.identifier ?? "USD"
            } else {
                code = Locale.current.currencyCode ?? "USD"
            }
            return amount.formatted(.currency(code: code))
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = Locale.current.currencyCode ?? "USD"
            return formatter.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
        }
    }
}

private enum HomeIncomeSavingsMetrics {
    static let labelFont: Font = .caption.weight(.semibold)
    static let valueFont: Font = .body.weight(.semibold)
    static let rowSpacing: CGFloat = 5
}

// MARK: - Section header + total row
private struct HomeSegmentTotalsRowView: View {
    let segment: BudgetDetailsViewModel.Segment
    let total: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(segment == .planned ? "PLANNED EXPENSES" : "VARIABLE EXPENSES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            Text(totalString)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var totalString: String {
        // Lightweight currency formatting; mirrors the helper used elsewhere
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            let code: String
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                code = Locale.current.currency?.identifier ?? "USD"
            } else {
                code = Locale.current.currencyCode ?? "USD"
            }
            return total.formatted(.currency(code: code))
        } else {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = Locale.current.currencyCode ?? "USD"
            return f.string(from: total as NSNumber) ?? String(format: "%.2f", total)
        }
    }
}

// MARK: - Segmented control sizing helpers
private extension View {
    func segmentedFill() -> some View { frame(maxWidth: .infinity) }
    func equalWidthSegments() -> some View { modifier(HomeEqualWidthSegmentsModifier()) }
}

private struct HomeEqualWidthSegmentsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(HomeEqualWidthSegmentApplier())
    }
}

private struct HomeEqualWidthSegmentApplier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: uiView) }
    }

    private func applyEqualWidthIfNeeded(from view: UIView) {
        guard let segmented = findSegmentedControl(from: view) else { return }
        segmented.apportionsSegmentWidthsByContent = false
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.invalidateIntrinsicContentSize()
    }

    private func findSegmentedControl(from view: UIView) -> UISegmentedControl? {
        var current: UIView? = view
        while let candidate = current {
            if let segmented = candidate as? UISegmentedControl { return segmented }
            current = candidate.superview
        }
        return nil
    }
}

// MARK: - Utility: Height measurement helper
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func measureHeight(_ binding: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { binding.wrappedValue = $0 }
    }
}
