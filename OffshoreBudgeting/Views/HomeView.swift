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
    @State private var headerContentHeight: CGFloat = 0

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
            spacing: headerContentSpacing
        ) {
            EmptyView()
        } content: { proxy in
            let availableContentHeight = resolvedAvailableContentHeight(using: proxy)

            VStack(alignment: .leading, spacing: headerContentSpacing) {
                headerSection
                contentContainer(
                    proxy: proxy,
                    availableContentHeight: availableContentHeight
                )
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .onPreferenceChange(HomeHeaderHeightPreferenceKey.self) { headerContentHeight = $0 }
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
        HomeHeaderOverviewTable(
            summary: primarySummary,
            displayTitle: periodHeaderTitle,
            displayDetail: periodRangeDetail,
            selectedSegment: $selectedSegment,
            sort: $homeSort,
            periodNavigationTitle: title(for: vm.selectedDate),
            onAdjustPeriod: { delta in vm.adjustSelectedPeriod(by: delta) }
        )
        .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: HomeHeaderHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
            }
        )
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
    private func contentContainer(proxy: RootTabPageProxy, availableContentHeight: CGFloat) -> some View {
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
                emptyPeriodContent(availableContentHeight: availableContentHeight)

            case .loaded(let summaries):
                if let first = summaries.first {
                    loadedBudgetContent(
                        for: first,
                        proxy: proxy,
                        availableContentHeight: availableContentHeight
                    )
                } else {
                    emptyPeriodContent(availableContentHeight: availableContentHeight)
                }
            }
        }
    }

    // MARK: Empty Period Content (replaces generic empty state)
    @ViewBuilder
    private func emptyPeriodContent(availableContentHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
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
        .frame(minHeight: availableContentHeight, alignment: .top)
    }

    @ViewBuilder
    private func loadedBudgetContent(
        for summary: BudgetSummary,
        proxy: RootTabPageProxy,
        availableContentHeight: CGFloat
    ) -> some View {
        let fallbackHeight = proxy.availableHeight - proxy.headerHeight
        let resolvedHeight = max(availableContentHeight > 0 ? availableContentHeight : fallbackHeight, 1)

        RootTabListHostingContainer(height: resolvedHeight) {
            BudgetDetailsView(
                budgetObjectID: summary.id,
                periodNavigation: nil,
                displaysBudgetTitle: false,
                headerTopPadding: DS.Spacing.xs,
                selectedSegment: $selectedSegment,
                sort: $homeSort,
                onSegmentChange: { newSegment in
                    self.selectedSegment = newSegment
                }
            )
            .id(summary.id)
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }


    private var headerSectionSpacing: CGFloat { DS.Spacing.xs / 2 }

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

    private var headerContentSpacing: CGFloat { DS.Spacing.s }

    private func resolvedAvailableContentHeight(using proxy: RootTabPageProxy) -> CGFloat {
        let spacingContribution = headerContentHeight > 0 ? headerContentSpacing : 0
        return max(proxy.availableHeight - headerContentHeight - spacingContribution, 0)
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

// MARK: - Home Header Overview Table
private struct HomeHeaderOverviewTable: View {
    let summary: BudgetSummary?
    let displayTitle: String
    let displayDetail: String
    @Binding var selectedSegment: BudgetDetailsViewModel.Segment
    @Binding var sort: BudgetDetailsViewModel.SortOption
    let periodNavigationTitle: String
    let onAdjustPeriod: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.sectionSpacing) {
            tableContent
            segmentPicker
            sortPicker
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tableContent: some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            Grid(horizontalSpacing: DS.Spacing.m, verticalSpacing: HomeHeaderOverviewMetrics.gridRowSpacing) {
                GridRow(alignment: .top) {
                    leadingGridCell { titleStack }
                    trailingGridCell { periodNavigationControlView }
                }

                incomeHeaderRow(title: "POTENTIAL INCOME", trailingTitle: "POTENTIAL SAVINGS")
                incomeValuesRow(
                    firstValue: potentialIncome,
                    firstColor: DS.Colors.plannedIncome,
                    secondValue: potentialSavings,
                    secondColor: DS.Colors.savingsGood
                )
                incomeHeaderRow(title: "ACTUAL INCOME", trailingTitle: "ACTUAL SAVINGS")
                incomeValuesRow(
                    firstValue: actualIncome,
                    firstColor: DS.Colors.actualIncome,
                    secondValue: actualSavings,
                    secondColor: DS.Colors.savingsGood
                )

                GridRow(alignment: .lastTextBaseline) {
                    leadingGridCell { totalLabelView }
                    trailingGridCell { totalValueView }
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            legacyTable
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.titleSpacing) {
            Text(displayTitle)
                .font(HomeHeaderOverviewMetrics.titleFont)
                .lineLimit(HomeHeaderOverviewMetrics.titleLineLimit)
                .minimumScaleFactor(HomeHeaderOverviewMetrics.titleMinimumScaleFactor)

            Text(displayDetail)
                .font(HomeHeaderOverviewMetrics.subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(HomeHeaderOverviewMetrics.subtitleLineLimit)
                .minimumScaleFactor(HomeHeaderOverviewMetrics.subtitleMinimumScaleFactor)
        }
        .accessibilityElement(children: .combine)
    }

    private var periodNavigationControlView: some View {
        PeriodNavigationControl(
            title: periodNavigationTitle,
            onPrevious: { onAdjustPeriod(-1) },
            onNext: { onAdjustPeriod(+1) }
        )
        .padding(.top, HomeHeaderOverviewMetrics.periodNavigationTopPadding)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func incomeHeaderRow(title: String, trailingTitle: String) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell {
                Text(title)
                    .font(HomeHeaderOverviewMetrics.labelFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            trailingGridCell {
                Text(trailingTitle)
                    .font(HomeHeaderOverviewMetrics.labelFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func incomeValuesRow(
        firstValue: Double,
        firstColor: Color,
        secondValue: Double,
        secondColor: Color
    ) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell {
                Text(formatCurrency(firstValue))
                    .font(HomeHeaderOverviewMetrics.valueFont)
                    .foregroundStyle(firstColor)
                    .lineLimit(1)
            }
            trailingGridCell {
                Text(formatCurrency(secondValue))
                    .font(HomeHeaderOverviewMetrics.valueFont)
                    .foregroundStyle(secondColor)
                    .lineLimit(1)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    private func leadingGridCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    private func trailingGridCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var totalLabelView: some View {
        Text(selectedSegment == .planned ? "PLANNED EXPENSES" : "VARIABLE EXPENSES")
            .font(HomeHeaderOverviewMetrics.labelFont)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .lineLimit(1)
    }

    private var totalValueView: some View {
        Text(formatCurrency(selectedSegmentTotal))
            .font(HomeHeaderOverviewMetrics.totalValueFont)
            .lineLimit(1)
    }

    private var legacyTable: some View {
        VStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.sectionSpacing) {
            HStack(alignment: .top, spacing: HomeHeaderOverviewMetrics.legacyColumnSpacing) {
                titleStack
                Spacer(minLength: 0)
                periodNavigationControlView
            }

            HStack(alignment: .top, spacing: HomeHeaderOverviewMetrics.legacyColumnSpacing) {
                VStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.legacyRowSpacing) {
                    legacyHeader("POTENTIAL INCOME")
                    legacyValue(potentialIncome, color: DS.Colors.plannedIncome)
                    legacyHeader("ACTUAL INCOME")
                    legacyValue(actualIncome, color: DS.Colors.actualIncome)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: HomeHeaderOverviewMetrics.legacyRowSpacing) {
                    legacyHeader("POTENTIAL SAVINGS")
                    legacyValue(potentialSavings, color: DS.Colors.savingsGood)
                    legacyHeader("ACTUAL SAVINGS")
                    legacyValue(actualSavings, color: DS.Colors.savingsGood)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(alignment: .firstTextBaseline) {
                totalLabelView
                Spacer()
                totalValueView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segmentPicker: some View {
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
    }

    private var sortPicker: some View {
        GlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s, alignment: .center) {
            Picker("Sort", selection: $sort) {
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
    }

    private func legacyHeader(_ title: String) -> some View {
        Text(title)
            .font(HomeHeaderOverviewMetrics.labelFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func legacyValue(_ amount: Double, color: Color) -> some View {
        Text(formatCurrency(amount))
            .font(HomeHeaderOverviewMetrics.valueFont)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private var potentialIncome: Double { summary?.potentialIncomeTotal ?? 0 }
    private var potentialSavings: Double { summary?.potentialSavingsTotal ?? 0 }
    private var actualIncome: Double { summary?.actualIncomeTotal ?? 0 }
    private var actualSavings: Double { summary?.actualSavingsTotal ?? 0 }
    private var plannedExpensesTotal: Double { summary?.plannedExpensesActualTotal ?? 0 }
    private var variableExpensesTotal: Double { summary?.variableExpensesTotal ?? 0 }
    private var selectedSegmentTotal: Double { selectedSegment == .planned ? plannedExpensesTotal : variableExpensesTotal }

    private func formatCurrency(_ amount: Double) -> String {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            let currencyCode: String
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                currencyCode = Locale.current.currency?.identifier ?? HomeHeaderOverviewMetrics.fallbackCurrencyCode
            } else {
                currencyCode = Locale.current.currencyCode ?? HomeHeaderOverviewMetrics.fallbackCurrencyCode
            }
            return amount.formatted(.currency(code: currencyCode))
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = Locale.current.currencyCode ?? HomeHeaderOverviewMetrics.fallbackCurrencyCode
            return formatter.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
        }
    }
}

private enum HomeHeaderOverviewMetrics {
    static let sectionSpacing: CGFloat = DS.Spacing.m
    static let gridRowSpacing: CGFloat = DS.Spacing.xs
    static let titleSpacing: CGFloat = DS.Spacing.xs / 2
    static let legacyColumnSpacing: CGFloat = DS.Spacing.m
    static let legacyRowSpacing: CGFloat = 5
    static let periodNavigationTopPadding: CGFloat = DS.Spacing.xs / 2
    static let titleFont: Font = .largeTitle.bold()
    static let titleLineLimit: Int = 2
    static let titleMinimumScaleFactor: CGFloat = 0.75
    static let subtitleFont: Font = .callout
    static let subtitleLineLimit: Int = 1
    static let subtitleMinimumScaleFactor: CGFloat = 0.85
    static let labelFont: Font = .caption.weight(.semibold)
    static let valueFont: Font = .body.weight(.semibold)
    static let totalValueFont: Font = .title3.weight(.semibold)
    static let fallbackCurrencyCode = "USD"
}

private struct HomeHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(0, nextValue())
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
