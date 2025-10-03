//
//  HomeView.swift
//  SoFar
//
//  Displays month header and, when a budget exists for the selected month,
//  shows the full BudgetDetailsView inline. Otherwise an empty state encourages
//  creating a budget.
//
//  Scroll behaviour:
//  - RootTabPageScaffold now manages the primary scroll host so large titles
//    collapse naturally.
//  - BudgetDetailsView accepts the home header so the summary and expense lists
//    share a single scroll container.
//  - Empty periods reuse the same header and place their CTA directly beneath
//    the sort controls for consistent alignment.
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
    @State private var isPresentingManageCategories: Bool = false

    // MARK: Body
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        // Sticky header is managed by RootTabPageScaffold.
        // - Empty states leverage the scaffold's scroll view for reachability.
        // - Loaded budgets embed the overview header within BudgetDetailsView so
        //   the summary and expense lists share a single scroll container.
        RootTabPageScaffold(
            scrollBehavior: requiresScaffoldScrollHosting ? .always : .auto,
            spacing: 0,
            wrapsContentInScrollView: requiresScaffoldScrollHosting
        ) { _ in
            EmptyView()
        } content: { proxy in
            contentContainer(proxy: proxy)
                .frame(maxWidth: .infinity, alignment: .top)
                .rootTabContentPadding(
                    proxy,
                    horizontal: 0,
                    includeSafeArea: false,
                    tabBarGutter: proxy.compactAwareTabBarGutter
                )
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Order: ellipsis, calendar, plus
                if let periodSummary = actionableSummaryForSelectedPeriod {
                    optionsToolbarMenu(summary: periodSummary)
                } else {
                    optionsToolbarMenu()
                }

                calendarToolbarMenu()

                if let active = actionableSummaryForSelectedPeriod {
                    addExpenseToolbarMenu(for: active.id)
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
        .sheet(isPresented: $isPresentingManageCategories) {
            ExpenseCategoryManagerView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .alert(item: $vm.alert, content: alert(for:))
    }

    private func homeHeaderPage<Content: View>(
        for summary: BudgetSummary?,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        @ViewBuilder content: @escaping (AnyView) -> Content
    ) -> some View {
        HomeHeaderTablePage(
            summary: summary,
            displayTitle: periodHeaderTitle,
            displayDetail: periodRangeDetail,
            categorySpending: headerCategoryBreakdown(for: summary),
            selectedSegment: $selectedSegment,
            sort: $homeSort,
            periodNavigationTitle: title(for: vm.selectedDate),
            onAdjustPeriod: { delta in vm.adjustSelectedPeriod(by: delta) },
            onAddCategory: { isPresentingManageCategories = true },
            topPaddingStyle: topPaddingStyle,
            content: content
        )
    }

    // MARK: Toolbar Actions
    private func calendarToolbarMenu() -> some View {
        Menu {
            ForEach(BudgetPeriod.selectableCases) { period in
                Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
            }
        } label: {
            HeaderMenuGlassLabel(systemImage: "calendar")
                .accessibilityLabel(budgetPeriod.displayName)
        }
        .modifier(HideMenuIndicatorIfPossible())
        .accessibilityLabel(budgetPeriod.displayName)
    }

    private func addExpenseToolbarMenu() -> some View {
        Menu {
            Button("Add Planned Expense") { isPresentingAddPlannedFromHome = true }
            Button("Add Variable Expense") { isPresentingAddVariableFromHome = true }
        } label: { HeaderMenuGlassLabel(systemImage: "plus") }
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
        } label: { HeaderMenuGlassLabel(systemImage: "plus") }
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
        } label: { HeaderMenuGlassLabel(systemImage: "ellipsis") }
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
        } label: { HeaderMenuGlassLabel(systemImage: "ellipsis", symbolVariants: SymbolVariants.none) }
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
                if let primary = selectPrimarySummary(from: summaries) {
                    loadedBudgetContent(for: primary)
                } else {
                    emptyPeriodContent(proxy: proxy)
                }
            }
        }
    }

    // MARK: Empty Period Content (replaces generic empty state)
    @ViewBuilder
    private func emptyPeriodContent(proxy: RootTabPageProxy) -> some View {
        let availableContentHeight = proxy.availableHeightBelowHeader

        homeHeaderPage(for: nil) { header in
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                header

                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    // Always-offer Add button when no budget exists so users can
                    // quickly create an expense for this period.
                    Group {
                        if #available(iOS 26.0, macCatalyst 26.0, *) {
                            Button(action: addExpenseCTAAction) {
                                Label(addExpenseCTATitle, systemImage: "plus")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .frame(
                                maxWidth: .infinity,
                                minHeight: HomeHeaderOverviewMetrics.categoryControlHeight
                            )
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.glass)
                            .tint(themeManager.selectedTheme.resolvedTint)
                        } else {
                            Button(action: addExpenseCTAAction) {
                                Label(addExpenseCTATitle, systemImage: "plus")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .accessibilityIdentifier("emptyPeriodAddExpenseCTA")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)

                    // Segment-specific guidance — centered consistently across platforms
                    Text(emptyShellMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)

                    Spacer(minLength: 0)
                }
                // Horizontal padding applied to individual rows above for precise matching
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: availableContentHeight, alignment: .top)
        }
    }

    @ViewBuilder
    private func loadedBudgetContent(
        for summary: BudgetSummary
    ) -> some View {
        homeHeaderPage(for: summary, topPaddingStyle: .contentEmbedded) { header in
            BudgetDetailsView(
                budgetObjectID: summary.id,
                periodNavigation: nil,
                displaysBudgetTitle: false,
                headerTopPadding: DS.Spacing.xs,
                appliesSurfaceBackground: false,
                showsCategoryChips: false,
                selectedSegment: $selectedSegment,
                sort: $homeSort,
                onSegmentChange: { newSegment in
                    self.selectedSegment = newSegment
                },
                headerManagesPadding: true,
                header: header,
                listHeaderBehavior: .omitsHeader,
                initialFilterRange: filterOverrideRangeForCurrentSelection
            )
            .id(summary.id)
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
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

    private func headerCategoryBreakdown(for summary: BudgetSummary?) -> [BudgetSummary.CategorySpending] {
        guard let summary else { return [] }
        if selectedSegment == .planned {
            return summary.plannedCategoryBreakdown
        } else {
            return summary.variableCategoryBreakdown
        }
    }

    private var primarySummary: BudgetSummary? {
        if case .loaded(let summaries) = vm.state {
            return selectPrimarySummary(from: summaries)
        }
        return nil
    }

    // Summary that is considered "active" for the currently selected period
    // (exact canonical match or same period type containing the selected date).
    private var actionableSummaryForSelectedPeriod: BudgetSummary? {
        if case .loaded(let summaries) = vm.state {
            return selectActionableSummary(from: summaries)
        }
        return nil
    }

    /// Choose the most relevant budget summary for the current Home selection.
    /// Preference order:
    /// 1) Exact match to the selected period's canonical start/end for `vm.selectedDate`.
    /// 2) A summary whose detected period type matches the selected period and contains `vm.selectedDate`.
    /// 3) Fallback to the earliest (current behavior via `.first`).
    private func selectPrimarySummary(from summaries: [BudgetSummary]) -> BudgetSummary? {
        guard !summaries.isEmpty else { return nil }

        let cal = Calendar.current
        let selectedPeriod = budgetPeriod
        let (selStart, selEnd) = selectedPeriod.range(containing: vm.selectedDate)

        // 1) Exact match to canonical range for the selected period
        if let exact = summaries.first(where: { s in
            cal.isDate(s.periodStart, inSameDayAs: selStart) && cal.isDate(s.periodEnd, inSameDayAs: selEnd)
        }) {
            return exact
        }

        // 2) Match by detected period type and containment of selected date
        if let typeMatch = summaries.first(where: { s in
            let detected = BudgetPeriod.selectableCases.first { $0.matches(startDate: s.periodStart, endDate: s.periodEnd) }
            let containsSelected = (s.periodStart ... s.periodEnd).contains(vm.selectedDate)
            return detected == selectedPeriod && containsSelected
        }) {
            return typeMatch
        }

        // 3) Fallback: maintain current behavior
        return summaries.first
    }

    /// Returns a summary only if it matches the selected period exactly or by type.
    /// This is used to decide whether the options menu should present Edit actions,
    /// otherwise it will offer Create Budget.
    private func selectActionableSummary(from summaries: [BudgetSummary]) -> BudgetSummary? {
        guard !summaries.isEmpty else { return nil }
        let cal = Calendar.current
        let selectedPeriod = budgetPeriod
        let (selStart, selEnd) = selectedPeriod.range(containing: vm.selectedDate)

        if let exact = summaries.first(where: { s in
            cal.isDate(s.periodStart, inSameDayAs: selStart) && cal.isDate(s.periodEnd, inSameDayAs: selEnd)
        }) {
            return exact
        }
        if let typeMatch = summaries.first(where: { s in
            let detected = BudgetPeriod.selectableCases.first { $0.matches(startDate: s.periodStart, endDate: s.periodEnd) }
            let containsSelected = (s.periodStart ... s.periodEnd).contains(vm.selectedDate)
            return detected == selectedPeriod && containsSelected
        }) {
            return typeMatch
        }
        return nil
    }

    private var requiresScaffoldScrollHosting: Bool {
        primarySummary == nil
    }

    // For Daily/Weekly/Bi-Weekly, align the BudgetDetailsView lists to the
    // selected period range. Monthly/Quarterly/Yearly: keep default.
    private var filterOverrideRangeForCurrentSelection: ClosedRange<Date>? {
        switch budgetPeriod {
        case .daily, .weekly, .biWeekly:
            let (start, end) = budgetPeriod.range(containing: vm.selectedDate)
            return start...end
        default:
            return nil
        }
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

// MARK: - Home Header Table Page
private struct HomeHeaderTablePage<Content: View>: View {
    @Environment(\.platformCapabilities) private var capabilities
    @Environment(\.responsiveLayoutContext) private var layoutContext

    let summary: BudgetSummary?
    let displayTitle: String
    let displayDetail: String
    let categorySpending: [BudgetSummary.CategorySpending]
    @Binding var selectedSegment: BudgetDetailsViewModel.Segment
    @Binding var sort: BudgetDetailsViewModel.SortOption
    let periodNavigationTitle: String
    let onAdjustPeriod: (Int) -> Void
    let onAddCategory: () -> Void
    let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle
    let content: (AnyView) -> Content

    var body: some View {
        let header = AnyView(headerContent)
        return content(header)
    }

    private var headerContent: some View {
        let horizontalPadding = HomeHeaderOverviewMetrics.horizontalPadding(
            for: capabilities,
            layoutContext: layoutContext
        )

        return VStack(spacing: HomeHeaderOverviewMetrics.sectionSpacing) {
            RootViewTopPlanes(
                title: "Home",
                titleDisplayMode: .hidden,
                horizontalPadding: horizontalPadding,
                topPaddingStyle: topPaddingStyle
            )

            HomeHeaderOverviewTable(
                summary: summary,
                displayTitle: displayTitle,
                displayDetail: displayDetail,
                categorySpending: categorySpending,
                selectedSegment: $selectedSegment,
                sort: $sort,
                periodNavigationTitle: periodNavigationTitle,
                onAdjustPeriod: onAdjustPeriod,
                onAddCategory: onAddCategory
            )
            .padding(.horizontal, horizontalPadding)
        }
    }
}

// MARK: - Home Header Overview Table
private struct HomeHeaderOverviewTable: View {
    let summary: BudgetSummary?
    let displayTitle: String
    let displayDetail: String
    let categorySpending: [BudgetSummary.CategorySpending]
    @Binding var selectedSegment: BudgetDetailsViewModel.Segment
    @Binding var sort: BudgetDetailsViewModel.SortOption
    let periodNavigationTitle: String
    let onAdjustPeriod: (Int) -> Void
    let onAddCategory: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.sectionSpacing) {
            titleRow
            periodNavigationRow
            metricsSection
            categoryRow
            segmentPicker
            sortPicker
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.titleSpacing) {
            Text(displayTitle)
                .font(HomeHeaderOverviewMetrics.titleFont)
                .lineLimit(HomeHeaderOverviewMetrics.titleLineLimit)
                .layoutPriority(2)
                .minimumScaleFactor(HomeHeaderOverviewMetrics.titleMinimumScaleFactor)

            Text(displayDetail)
                .font(HomeHeaderOverviewMetrics.subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(HomeHeaderOverviewMetrics.subtitleLineLimit)
                .layoutPriority(0)
                .minimumScaleFactor(HomeHeaderOverviewMetrics.subtitleMinimumScaleFactor)
        }
        .accessibilityElement(children: .combine)
    }

    private var periodNavigationRow: some View {
        PeriodNavigationControl(
            title: periodNavigationTitle,
            onPrevious: { onAdjustPeriod(-1) },
            onNext: { onAdjustPeriod(+1) }
        )
        .frame(maxWidth: .infinity)
        .padding(.top, HomeHeaderOverviewMetrics.titleToPeriodNavigationSpacing)
    }

    private var metricsSection: some View {
        LazyVStack(alignment: .leading, spacing: HomeHeaderOverviewMetrics.metricRowSpacing) {
            HomeHeaderTableTwoColumnRow {
                metricHeader("POTENTIAL INCOME")
            } trailing: {
                metricHeader("POTENTIAL SAVINGS")
            }

            HomeHeaderTableTwoColumnRow {
                metricValue(potentialIncome, color: DS.Colors.plannedIncome)
            } trailing: {
                metricValue(potentialSavings, color: DS.Colors.savingsGood)
            }

            Group {
                HomeHeaderTableTwoColumnRow {
                    metricHeader("ACTUAL INCOME")
                } trailing: {
                    metricHeader("ACTUAL SAVINGS")
                }

                HomeHeaderTableTwoColumnRow {
                    metricValue(actualIncome, color: DS.Colors.actualIncome)
                } trailing: {
                    metricValue(actualSavings, color: DS.Colors.savingsGood)
                }
            }
            .padding(.top, HomeHeaderOverviewMetrics.metricGroupSpacing)

            HomeHeaderTableTwoColumnRow {
                totalLabelView
            } trailing: {
                totalValueView
            }
            .padding(.top, HomeHeaderOverviewMetrics.metricGroupSpacing)
        }
    }

    private var categoryRow: some View {
        Group {
            if categorySpending.isEmpty {
                // Full-width, pressable capsule to prompt adding a category
                GlassCapsuleContainer(
                    horizontalPadding: DS.Spacing.l,
                    verticalPadding: DS.Spacing.s,
                    alignment: .center
                ) {
                    Button(action: onAddCategory) {
                        Label("Add Category", systemImage: "plus")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(
                                maxWidth: .infinity,
                                minHeight: HomeHeaderOverviewMetrics.categoryControlHeight
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home_add_category_cta")
                }
                .frame(height: HomeHeaderOverviewMetrics.categoryControlHeight)
            } else {
                CategoryTotalsRow(
                    categories: categorySpending,
                    isPlaceholder: false,
                    horizontalInset: 0
                )
                .frame(height: HomeHeaderOverviewMetrics.categoryControlHeight)
            }
        }
        .padding(.top, HomeHeaderOverviewMetrics.categoryChipTopSpacing)
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

    private func metricHeader(_ title: String) -> some View {
        Text(title)
            .font(HomeHeaderOverviewMetrics.labelFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func metricValue(_ amount: Double, color: Color) -> some View {
        Text(formatCurrency(amount))
            .font(HomeHeaderOverviewMetrics.valueFont)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private var segmentPicker: some View {
        GlassCapsuleContainer(
            horizontalPadding: HomeHeaderOverviewMetrics.controlHorizontalPadding,
            verticalPadding: HomeHeaderOverviewMetrics.controlVerticalPadding
        ) {
            Picker("", selection: $selectedSegment) {
                Text("Planned Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.planned)
                Text("Variable Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.variable)
            }
            .pickerStyle(.segmented)
            .equalWidthSegments()
            .frame(maxWidth: .infinity)
        }
    }

    private var sortPicker: some View {
        GlassCapsuleContainer(
            horizontalPadding: HomeHeaderOverviewMetrics.controlHorizontalPadding,
            verticalPadding: HomeHeaderOverviewMetrics.controlVerticalPadding,
            alignment: .center
        ) {
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
        }
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

private struct HomeHeaderTableTwoColumnRow<Leading: View, Trailing: View>: View {
    private let alignment: VerticalAlignment
    private let leading: () -> Leading
    private let trailing: () -> Trailing

    init(
        alignment: VerticalAlignment = .lastTextBaseline,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.alignment = alignment
               self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: alignment, spacing: DS.Spacing.m) {
            leading()
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Header Menu Glass Label (OS26)
private struct HeaderMenuGlassLabel: View {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    var systemImage: String
    var symbolVariants: SymbolVariants? = nil

    var body: some View {
        if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
            RootHeaderGlassControl(sizing: .icon) {
                RootHeaderControlIcon(systemImage: systemImage, symbolVariants: symbolVariants)
            }
            .tint(themeManager.selectedTheme.resolvedTint)
        } else {
            RootHeaderGlassControl(sizing: .icon) {
                RootHeaderControlIcon(systemImage: systemImage, symbolVariants: symbolVariants)
            }
        }
    }
}

private enum HomeHeaderOverviewMetrics {
    static let sectionSpacing: CGFloat = DS.Spacing.m
    static let titleSpacing: CGFloat = DS.Spacing.xs / 2
    static let titleToPeriodNavigationSpacing: CGFloat = DS.Spacing.xs / 2
    static let metricRowSpacing: CGFloat = DS.Spacing.xs
    static let metricGroupSpacing: CGFloat = DS.Spacing.xs
    static let categoryChipTopSpacing: CGFloat = DS.Spacing.s
    static let categoryControlHeight: CGFloat = 44
    static let controlHorizontalPadding: CGFloat = DS.Spacing.s
    static let controlVerticalPadding: CGFloat = DS.Spacing.s
    static let titleFont: Font = .largeTitle.bold()
    static let titleLineLimit: Int = 1
    static let titleMinimumScaleFactor: CGFloat = 0.6
    static let subtitleFont: Font = .callout
    static let subtitleLineLimit: Int = 1
    static let subtitleMinimumScaleFactor: CGFloat = 0.75
    static let labelFont: Font = .caption.weight(.semibold)
    static let valueFont: Font = .body.weight(.semibold)
    static let totalValueFont: Font = .title3.weight(.semibold)
    static let fallbackCurrencyCode = "USD"

    static func horizontalPadding(
        for capabilities: PlatformCapabilities,
        layoutContext: ResponsiveLayoutContext
    ) -> CGFloat {
        if capabilities.supportsOS26Translucency {
            return RootTabHeaderLayout.defaultHorizontalPadding
        }

        if layoutContext.containerSize.width >= 600 {
            return RootTabHeaderLayout.defaultHorizontalPadding
        }

        return max(layoutContext.safeArea.leading, 0)
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
