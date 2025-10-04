//
//  BudgetDetailsView.swift
//  SoFar
//
//  Budget details with live Core Data-backed lists.
//  Planned & Variable expenses now use SwiftUI List to enable native swipe gestures.
//  UnifiedSwipeActions gives consistent titles/icons and Mail-style full-swipe on iOS.
//

import SwiftUI
import UIKit
import CoreData
import Combine
// MARK: - BudgetDetailsView
/// Shows a budget header, filters, and a segmented control to switch between
/// Planned and Variable (Unplanned) expenses. Rows live in real Lists so swipe
/// gestures work on iOS/iPadOS and macOS 13+.
struct BudgetDetailsView: View {

    // MARK: Inputs
    let budgetObjectID: NSManagedObjectID
    struct PeriodNavigationConfiguration {
        let title: String
        let onAdjust: (Int) -> Void
    }
    private let periodNavigation: PeriodNavigationConfiguration?
    private let displaysBudgetTitle: Bool
    private let headerTopPadding: CGFloat
    private let appliesSurfaceBackground: Bool
    private let showsCategoryChips: Bool
    let onSegmentChange: ((BudgetDetailsViewModel.Segment) -> Void)?
    enum ListHeaderBehavior {
        case rendersHeader
        case omitsHeader
    }

    private let embeddedListHeader: AnyView?
    private let embeddedHeaderManagesPadding: Bool
    private let listHeaderBehavior: ListHeaderBehavior
    // Optional: override the initial date window shown by the lists
    private let initialFilterRange: ClosedRange<Date>?
    @Binding private var externalSelectedSegment: BudgetDetailsViewModel.Segment
    @Binding private var externalSort: BudgetDetailsViewModel.SortOption

    // MARK: View Model
    @StateObject private var vm: BudgetDetailsViewModel

    // MARK: Theme
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.platformCapabilities) private var capabilities

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    // MARK: UI State
    @State private var isPresentingAddPlannedSheet = false
    @State private var isPresentingAddUnplannedSheet = false
    @State private var didTriggerInitialLoad = false
    @State private var isPresentingManageCategories = false
    @State private var didApplyFilterOverride = false

    // MARK: Layout
    private var isWideHeaderLayout: Bool {
#if os(iOS)
    #if targetEnvironment(macCatalyst)
        return true
    #else
        return horizontalSizeClass == .regular
    #endif
#else
        return false
#endif
    }

    private var headerSpacing: CGFloat {
        return isWideHeaderLayout ? DS.Spacing.xs : DS.Spacing.s
    }

    private var effectiveHeaderTopPadding: CGFloat {
        return max(0, headerTopPadding - headerTopPaddingAdjustment)
    }

    private var headerTopPaddingAdjustment: CGFloat {
        return isWideHeaderLayout ? DS.Spacing.xs : DS.Spacing.xs / 2
    }

    private var layoutContextForInsets: ResponsiveLayoutContext? {
        layoutContext.containerSize.width > 0 ? layoutContext : nil
    }

    private var headerHorizontalInsets: BudgetListHorizontalPaddingMetrics.Insets {
        BudgetListHorizontalPaddingMetrics.resolvedInsets(
            for: capabilities,
            layoutContext: layoutContextForInsets
        )
    }

    private var shouldShowPeriodNavigation: Bool {
        guard periodNavigation != nil else { return false }
        guard vm.budget?.startDate != nil, vm.budget?.endDate != nil else { return false }
        return true
    }

    // MARK: Init
    init(
        budgetObjectID: NSManagedObjectID,
        periodNavigation: PeriodNavigationConfiguration? = nil,
        displaysBudgetTitle: Bool = true,
        headerTopPadding: CGFloat = DS.Spacing.s,
        appliesSurfaceBackground: Bool = true,
        showsCategoryChips: Bool = true,
        selectedSegment: Binding<BudgetDetailsViewModel.Segment>,
        sort: Binding<BudgetDetailsViewModel.SortOption>,
        onSegmentChange: ((BudgetDetailsViewModel.Segment) -> Void)? = nil,
        headerManagesPadding: Bool = false,
        header: AnyView? = nil,
        listHeaderBehavior: ListHeaderBehavior = .rendersHeader,
        initialFilterRange: ClosedRange<Date>? = nil
    ) {
        self.budgetObjectID = budgetObjectID
        self.periodNavigation = periodNavigation
        self.displaysBudgetTitle = displaysBudgetTitle
        self.headerTopPadding = headerTopPadding
        self.appliesSurfaceBackground = appliesSurfaceBackground
        self.showsCategoryChips = showsCategoryChips
        self.onSegmentChange = onSegmentChange
        self.embeddedListHeader = header
        self.embeddedHeaderManagesPadding = headerManagesPadding
        self.listHeaderBehavior = listHeaderBehavior
        self.initialFilterRange = initialFilterRange
        _externalSelectedSegment = selectedSegment
        _externalSort = sort
        _vm = StateObject(wrappedValue: BudgetDetailsViewModelStore.shared.viewModel(for: budgetObjectID))
    }

    /// Alternate initializer that accepts an existing, cached view model.
    init(
        viewModel: BudgetDetailsViewModel,
        periodNavigation: PeriodNavigationConfiguration? = nil,
        displaysBudgetTitle: Bool = true,
        headerTopPadding: CGFloat = DS.Spacing.s,
        appliesSurfaceBackground: Bool = true,
        showsCategoryChips: Bool = true,
        selectedSegment: Binding<BudgetDetailsViewModel.Segment>,
        sort: Binding<BudgetDetailsViewModel.SortOption>,
        onSegmentChange: ((BudgetDetailsViewModel.Segment) -> Void)? = nil,
        headerManagesPadding: Bool = false,
        header: AnyView? = nil,
        listHeaderBehavior: ListHeaderBehavior = .rendersHeader,
        initialFilterRange: ClosedRange<Date>? = nil
    ) {
        self.budgetObjectID = viewModel.budgetObjectID
        self.periodNavigation = periodNavigation
        self.displaysBudgetTitle = displaysBudgetTitle
        self.headerTopPadding = headerTopPadding
        self.appliesSurfaceBackground = appliesSurfaceBackground
        self.showsCategoryChips = showsCategoryChips
        self.onSegmentChange = onSegmentChange
        self.embeddedListHeader = header
        self.embeddedHeaderManagesPadding = headerManagesPadding
        self.listHeaderBehavior = listHeaderBehavior
        self.initialFilterRange = initialFilterRange
        _externalSelectedSegment = selectedSegment
        _externalSort = sort
        _vm = StateObject(wrappedValue: viewModel)
    }

    init<Header: View>(
        budgetObjectID: NSManagedObjectID,
        periodNavigation: PeriodNavigationConfiguration? = nil,
        displaysBudgetTitle: Bool = true,
        headerTopPadding: CGFloat = DS.Spacing.s,
        appliesSurfaceBackground: Bool = true,
        showsCategoryChips: Bool = true,
        selectedSegment: Binding<BudgetDetailsViewModel.Segment>,
        sort: Binding<BudgetDetailsViewModel.SortOption>,
        onSegmentChange: ((BudgetDetailsViewModel.Segment) -> Void)? = nil,
        headerManagesPadding: Bool = false,
        listHeaderBehavior: ListHeaderBehavior = .rendersHeader,
        @ViewBuilder header headerBuilder: @escaping () -> Header,
        initialFilterRange: ClosedRange<Date>? = nil
    ) {
        self.init(
            budgetObjectID: budgetObjectID,
            periodNavigation: periodNavigation,
            displaysBudgetTitle: displaysBudgetTitle,
            headerTopPadding: headerTopPadding,
            appliesSurfaceBackground: appliesSurfaceBackground,
            showsCategoryChips: showsCategoryChips,
            selectedSegment: selectedSegment,
            sort: sort,
            onSegmentChange: onSegmentChange,
            headerManagesPadding: headerManagesPadding,
            header: AnyView(headerBuilder()),
            listHeaderBehavior: listHeaderBehavior,
            initialFilterRange: initialFilterRange
        )
    }

    init<Header: View>(
        viewModel: BudgetDetailsViewModel,
        periodNavigation: PeriodNavigationConfiguration? = nil,
        displaysBudgetTitle: Bool = true,
        headerTopPadding: CGFloat = DS.Spacing.s,
        appliesSurfaceBackground: Bool = true,
        showsCategoryChips: Bool = true,
        selectedSegment: Binding<BudgetDetailsViewModel.Segment>,
        sort: Binding<BudgetDetailsViewModel.SortOption>,
        onSegmentChange: ((BudgetDetailsViewModel.Segment) -> Void)? = nil,
        headerManagesPadding: Bool = false,
        listHeaderBehavior: ListHeaderBehavior = .rendersHeader,
        @ViewBuilder header headerBuilder: @escaping () -> Header,
        initialFilterRange: ClosedRange<Date>? = nil
    ) {
        self.init(
            viewModel: viewModel,
            periodNavigation: periodNavigation,
            displaysBudgetTitle: displaysBudgetTitle,
            headerTopPadding: headerTopPadding,
            appliesSurfaceBackground: appliesSurfaceBackground,
            showsCategoryChips: showsCategoryChips,
            selectedSegment: selectedSegment,
            sort: sort,
            onSegmentChange: onSegmentChange,
            headerManagesPadding: headerManagesPadding,
            header: AnyView(headerBuilder()),
            listHeaderBehavior: listHeaderBehavior,
            initialFilterRange: initialFilterRange
        )
    }

    // MARK: Body
    var body: some View {
        applySurfaceBackground(
            to: VStack(spacing: 0) {

            // Keep only a small top spacer to align with nav chrome
            Color.clear.frame(height: max(effectiveHeaderTopPadding - DS.Spacing.s, 0))

            // Always render the header above the list so its size/color
            // remains consistent whether items exist or not.
            if listHeaderBehavior == .rendersHeader {
                listHeader
            }

            // MARK: Lists
            Group {
                if vm.selectedSegment == .planned {
                    // Prefer a fresh instance from the context so we don't
                    // show a transient placeholder while the view model resolves.
                    if let budget = ((try? viewContext.existingObject(with: vm.budgetObjectID) as? Budget) ?? vm.budget) {
                        PlannedListFR(
                            budget: budget,
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            sort: vm.sort,
                            onAddTapped: { isPresentingAddPlannedSheet = true },
                            onTotalsChanged: { Task { await vm.refreshRows() } },
                            header: embeddedListHeader,
                            headerManagesPadding: embeddedHeaderManagesPadding
                        )
                    } else {
                        placeholderView()
                    }
                } else {
                    // Even if the budget hasn't fully resolved yet, render the
                    // variable list with an empty cards array so the user sees
                    // the proper empty state (with Add button) instead of a
                    // perpetual "Loading…" placeholder.
                    VariableListFR(
                        attachedCards: Array((vm.budget?.cards as? Set<Card>) ?? []),
                        startDate: vm.startDate,
                        endDate: vm.endDate,
                        sort: vm.sort,
                        onAddTapped: { isPresentingAddUnplannedSheet = true },
                        onTotalsChanged: { Task { await vm.refreshRows() } },
                        header: embeddedListHeader,
                        headerManagesPadding: embeddedHeaderManagesPadding
                    )
                }
            }
            // Ensure the lists/empty states receive an unconstrained vertical
            // proposal so they can own scrolling in both orientations.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Make the primary container expand to the viewport so inner Lists and
        // ScrollViews can scroll when height is constrained (e.g., landscape).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
        // Load once per view instance. Gate with local state to avoid
        // accidental re-entrant loads caused by view tree churn.
        .task {
            if !didTriggerInitialLoad {
                didTriggerInitialLoad = true
                CoreDataService.shared.ensureLoaded()
                await vm.load()
                // Apply an optional initial filter override once after load
                if !didApplyFilterOverride, let override = initialFilterRange {
                    didApplyFilterOverride = true
                    vm.startDate = override.lowerBound
                    vm.endDate = override.upperBound
                    await vm.refreshRows()
                }
            }
        }
        .onAppear(perform: synchronizeBindingsFromViewModel)
        .ub_onChange(of: externalSelectedSegment) { newValue in
            if vm.selectedSegment != newValue {
                vm.selectedSegment = newValue
            }
        }
        .ub_onChange(of: externalSort) { newValue in
            if vm.sort != newValue {
                vm.sort = newValue
            }
        }
        .ub_onChange(of: vm.selectedSegment) { newValue in
            if externalSelectedSegment != newValue {
                externalSelectedSegment = newValue
            }
            onSegmentChange?(newValue)
        }
        .ub_onChange(of: vm.sort) { newValue in
            if externalSort != newValue {
                externalSort = newValue
            }
        }
        // Pull-to-refresh is scoped to the Lists only (Planned/Variable).
        // Removing it here prevents the header (including the category chips)
        // from initiating a refresh gesture.
        .onReceive(
            NotificationCenter.default
                .publisher(for: .budgetDetailsRequestAddPlannedExpense)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let target = notification.object as? NSManagedObjectID,
                  target == budgetObjectID else { return }
            isPresentingAddPlannedSheet = true
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .budgetDetailsRequestAddVariableExpense)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let target = notification.object as? NSManagedObjectID,
                  target == budgetObjectID else { return }
            isPresentingAddUnplannedSheet = true
        }
        //.searchable(text: $vm.searchQuery, placement: .toolbar, prompt: Text("Search"))
        // MARK: Add Sheets
        .alert(item: $vm.alert, content: alert(for:))
        .sheet(isPresented: $isPresentingAddPlannedSheet) {
            AddPlannedExpenseView(
                preselectedBudgetID: vm.budget?.objectID,
                defaultSaveAsGlobalPreset: UserDefaults.standard.bool(forKey: AppSettingsKeys.presetsDefaultUseInFutureBudgets.rawValue),
                onSaved: { Task { await vm.refreshRows() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .sheet(isPresented: $isPresentingAddUnplannedSheet) {
            AddUnplannedExpenseView(
                allowedCardIDs: Set(((vm.budget?.cards as? Set<Card>) ?? []).map { $0.objectID }),
                initialDate: vm.startDate,
                onSaved: { Task { await vm.refreshRows() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        // Refresh rows when Core Data changes so category chips include newly added categories immediately
        .onReceive(
            NotificationCenter.default
                .publisher(for: .dataStoreDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            Task { await vm.refreshRows() }
        }
        // Manage categories sheet
        .sheet(isPresented: $isPresentingManageCategories) {
            ExpenseCategoryManagerView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    // MARK: Helpers
    private func synchronizeBindingsFromViewModel() {
        if externalSelectedSegment != vm.selectedSegment {
            externalSelectedSegment = vm.selectedSegment
        }

        if externalSort != vm.sort {
            externalSort = vm.sort
        }
    }

    private func placeholderView() -> some View {
        let text = vm.placeholderText.isEmpty ? "Loading…" : vm.placeholderText
        return Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.l)
            .multilineTextAlignment(.leading)
    }

    private func alert(for alert: BudgetDetailsViewModel.BudgetDetailsAlert) -> Alert {
        switch alert.kind {
        case .error(let message):
            return Alert(
                title: Text("Budget Unavailable"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func applySurfaceBackground<Content: View>(
        to content: Content
    ) -> some View {
        if appliesSurfaceBackground {
            content
                .ub_surfaceBackground(
                    themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration,
                    ignoringSafeArea: .all
                )
        } else {
            content
        }
    }

    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}

// (removed) Inline list header — Segment picker and sort controls now live in HomeView's shared header

// MARK: - Scrolling List Header Content
private extension BudgetDetailsView {
    @ViewBuilder
    var listHeader: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            // Title + Period Navigation (when configured)
            if displaysBudgetTitle || shouldShowPeriodNavigation {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    if displaysBudgetTitle {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.budget?.name ?? "Budget")
                                .font(.largeTitle.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let startDate = vm.budget?.startDate,
                               let endDate = vm.budget?.endDate {
                                Text("\(Self.mediumDate(startDate)) through \(Self.mediumDate(endDate))")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    if shouldShowPeriodNavigation, let navigation = periodNavigation {
                        Spacer(minLength: 0)
                        PeriodNavigationControl(
                            title: navigation.title,
                            onPrevious: { navigation.onAdjust(-1) },
                            onNext: { navigation.onAdjust(+1) }
                        )
                        .padding(.top, displaysBudgetTitle ? DS.Spacing.xs : 0)
                    }
                }
                .padding(.leading, headerHorizontalInsets.leading)
                .padding(.trailing, headerHorizontalInsets.trailing)
            }

            if showsCategoryChips, let summary = vm.summary {
                if vm.selectedSegment == .planned {
                    if summary.plannedCategoryBreakdown.isEmpty {
                        GlassCapsuleContainer(
                            horizontalPadding: headerHorizontalInsets.symmetricInset,
                            verticalPadding: DS.Spacing.s,
                            alignment: .center
                        ) {
                            Button(action: { isPresentingManageCategories = true }) {
                                Label("Add Category", systemImage: "plus")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("details_add_category_cta")
                        }
                        .frame(height: 34)
                    } else {
                        CategoryTotalsRow(
                            categories: summary.plannedCategoryBreakdown,
                            horizontalInset: headerHorizontalInsets.symmetricInset
                        )
                    }
                } else {
                    if summary.variableCategoryBreakdown.isEmpty {
                        GlassCapsuleContainer(
                            horizontalPadding: headerHorizontalInsets.symmetricInset,
                            verticalPadding: DS.Spacing.s,
                            alignment: .center
                        ) {
                            Button(action: { isPresentingManageCategories = true }) {
                                Label("Add Category", systemImage: "plus")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("details_add_category_cta")
                        }
                        .frame(height: 34)
                    } else {
                        CategoryTotalsRow(
                            categories: summary.variableCategoryBreakdown,
                            horizontalInset: headerHorizontalInsets.symmetricInset
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Combined Budget Header Grid (aligns all numeric totals)
private struct CombinedBudgetHeaderGrid: View {
    let summary: BudgetSummary
    let selectedSegment: BudgetDetailsViewModel.Segment
    let showsIncomeGrid: Bool

    var body: some View {
        Group {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                Grid(horizontalSpacing: DS.Spacing.m, verticalSpacing: BudgetIncomeSavingsSummaryMetrics.rowSpacing) {
                    if showsIncomeGrid {
                        headerRow(title: "POTENTIAL INCOME", title2: "POTENTIAL SAVINGS")
                        valuesRow(
                            firstValue: summary.potentialIncomeTotal,
                            firstColor: DS.Colors.plannedIncome,
                            secondValue: summary.potentialSavingsTotal,
                            secondColor: DS.Colors.savingsGood
                        )
                        headerRow(title: "ACTUAL INCOME", title2: "ACTUAL SAVINGS")
                        valuesRow(
                            firstValue: summary.actualIncomeTotal,
                            firstColor: DS.Colors.actualIncome,
                            secondValue: summary.actualSavingsTotal,
                            secondColor: summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad
                        )
                    }

                    // Planned/Variable total aligned to right column
                    GridRow(alignment: .lastTextBaseline) {
                        leadingGridCell {
                            Text(selectedSegment == .planned ? "PLANNED EXPENSES" : "VARIABLE EXPENSES")
                                .font(BudgetIncomeSavingsSummaryMetrics.labelFont)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .lineLimit(1)
                        }

                        trailingGridCell {
                            Text(totalString)
                                .font(BudgetIncomeSavingsSummaryMetrics.valueFont.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // Fallback: simple stacked layout with right-aligned totals
                VStack(spacing: 6) {
                    if showsIncomeGrid {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("POTENTIAL INCOME").font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: summary.potentialIncomeTotal))
                                    .font(BudgetIncomeSavingsSummaryMetrics.valueFont)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("POTENTIAL SAVINGS").font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: summary.potentialSavingsTotal))
                                    .font(BudgetIncomeSavingsSummaryMetrics.valueFont)
                            }
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ACTUAL INCOME").font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: summary.actualIncomeTotal))
                                    .font(BudgetIncomeSavingsSummaryMetrics.valueFont)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("ACTUAL SAVINGS").font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: summary.actualSavingsTotal))
                                    .font(BudgetIncomeSavingsSummaryMetrics.valueFont)
                            }
                        }
                    }

                    HStack {
                        Text(selectedSegment == .planned ? "PLANNED EXPENSES" : "VARIABLE EXPENSES")
                            .font(BudgetIncomeSavingsSummaryMetrics.labelFont)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text(totalString)
                            .font(BudgetIncomeSavingsSummaryMetrics.valueFont.weight(.semibold))
                    }
                }
            }
        }
    }

    private var totalString: String {
        let value = selectedSegment == .planned ? summary.plannedExpensesActualTotal : summary.variableExpensesTotal
        return CurrencyFormatterHelper.string(for: value)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func headerRow(title: String, title2: String) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { Text(title).font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary).lineLimit(1) }
            trailingGridCell { Text(title2).font(BudgetIncomeSavingsSummaryMetrics.labelFont).foregroundStyle(.secondary).lineLimit(1) }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func valuesRow(firstValue: Double, firstColor: Color, secondValue: Double, secondColor: Color) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { Text(CurrencyFormatterHelper.string(for: firstValue)).font(BudgetIncomeSavingsSummaryMetrics.valueFont).foregroundStyle(firstColor).lineLimit(1) }
            trailingGridCell { Text(CurrencyFormatterHelper.string(for: secondValue)).font(BudgetIncomeSavingsSummaryMetrics.valueFont).foregroundStyle(secondColor).lineLimit(1) }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func leadingGridCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) { content(); Spacer(minLength: 0) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func trailingGridCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) { Spacer(minLength: 0); content() }
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - SummarySection
private struct SummarySection: View {
    let summary: BudgetSummary
    let selectedSegment: BudgetDetailsViewModel.Segment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedSegment == .planned ? "Planned Expenses" : "Variable Expenses")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(CurrencyFormatterHelper.string(for: selectedSegment == .planned ? summary.plannedExpensesActualTotal : summary.variableExpensesTotal))
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}

struct BudgetIncomeSavingsSummaryView: View {
    let summary: BudgetSummary

    var body: some View {
        Group {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                Grid(horizontalSpacing: DS.Spacing.m, verticalSpacing: BudgetIncomeSavingsSummaryMetrics.rowSpacing) {
                    headerRow(title: "POTENTIAL INCOME", title2: "POTENTIAL SAVINGS")
                    valuesRow(
                        firstValue: summary.potentialIncomeTotal,
                        firstColor: DS.Colors.plannedIncome,
                        secondValue: summary.potentialSavingsTotal,
                        secondColor: DS.Colors.savingsGood
                    )
                    headerRow(title: "ACTUAL INCOME", title2: "ACTUAL SAVINGS")
                    valuesRow(
                        firstValue: summary.actualIncomeTotal,
                        firstColor: DS.Colors.actualIncome,
                        secondValue: summary.actualSavingsTotal,
                        secondColor: summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad
                    )
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    VStack(alignment: .leading, spacing: BudgetIncomeSavingsSummaryMetrics.rowSpacing) {
                        VStack(alignment: .leading) {
                            header(title: "POTENTIAL INCOME")
                            value(amount: summary.potentialIncomeTotal, color: DS.Colors.plannedIncome)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading) {
                            header(title: "ACTUAL INCOME")
                            value(amount: summary.actualIncomeTotal, color: DS.Colors.actualIncome)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: BudgetIncomeSavingsSummaryMetrics.rowSpacing) {
                        VStack(alignment: .trailing) {
                            header(title: "POTENTIAL SAVINGS")
                                .multilineTextAlignment(.trailing)
                            value(amount: summary.potentialSavingsTotal, color: DS.Colors.savingsGood)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(alignment: .trailing) {
                            header(title: "ACTUAL SAVINGS")
                                .multilineTextAlignment(.trailing)
                            value(amount: summary.actualSavingsTotal, color: summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func headerRow(title: String, title2: String) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell {
                header(title: title)
            }

            trailingGridCell {
                header(title: title2)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func valuesRow(firstValue: Double, firstColor: Color, secondValue: Double, secondColor: Color) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell {
                value(amount: firstValue, color: firstColor)
            }

            trailingGridCell {
                value(amount: secondValue, color: secondColor)
            }
        }
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func leadingGridCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 16.0, macCatalyst 16.0, *)
    @ViewBuilder
    private func trailingGridCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder
    private func header(title: String) -> some View {
        Text(title)
            .font(BudgetIncomeSavingsSummaryMetrics.labelFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
    
    @ViewBuilder
    private func value(amount: Double, color: Color) -> some View {
        Text(CurrencyFormatterHelper.string(for: amount))
            .font(BudgetIncomeSavingsSummaryMetrics.valueFont)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private enum BudgetIncomeSavingsSummaryMetrics {
    static let labelFont: Font = .caption.weight(.semibold)
    static let valueFont: Font = .body.weight(.semibold)
    static let minimumScaleFactor: CGFloat = 0.5
    static let rowSpacing: CGFloat = 5
    static let legacyColumnSpacing: CGFloat = 5
}

// MARK: - PlannedListFR (List-backed; swipe enabled)
private struct PlannedListFR: View {
    @FetchRequest private var rows: FetchedResults<PlannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    private let onAddTapped: () -> Void
    private let onTotalsChanged: () -> Void
    private let header: AnyView?
    private let headerManagesPadding: Bool
    @State private var editingItem: PlannedExpense?
    @State private var itemToDelete: PlannedExpense?
    @State private var showDeleteAlert = false

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    private var layoutContextForInsets: ResponsiveLayoutContext? {
        layoutContext.containerSize.width > 0 ? layoutContext : nil
    }

    private var listHorizontalInsets: BudgetListHorizontalPaddingMetrics.Insets {
        BudgetListHorizontalPaddingMetrics.resolvedInsets(
            for: capabilities,
            layoutContext: layoutContextForInsets
        )
    }

    init(
        budget: Budget,
        startDate: Date,
        endDate: Date,
        sort: BudgetDetailsViewModel.SortOption,
        onAddTapped: @escaping () -> Void,
        onTotalsChanged: @escaping () -> Void,
        header: AnyView? = nil,
        headerManagesPadding: Bool = false
    ) {
        self.sort = sort
        self.onAddTapped = onAddTapped
        self.onTotalsChanged = onTotalsChanged
        self.header = header
        self.headerManagesPadding = headerManagesPadding

        let (s, e) = Self.clamp(startDate...endDate)
        let req: NSFetchRequest<PlannedExpense> = NSFetchRequest(entityName: "PlannedExpense")
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "budget == %@", budget),
            NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@", s as NSDate, e as NSDate)
        ])
        req.sortDescriptors = [
            NSSortDescriptor(key: "transactionDate", ascending: false),
            NSSortDescriptor(key: "descriptionText", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        _rows = FetchRequest(fetchRequest: req, animation: .default)
    }

    var body: some View {
        // Compute the sorted array once outside of the List to avoid unintended
        // recomputations during the list diffing. This also makes the `isEmpty`
        // check straightforward.
        let items = sorted(rows)
        Group {
            if items.isEmpty {
                // MARK: Compact empty state (single Add button)
                List {
                    if let header {
                        headerSection(header, applyDefaultInsets: !headerManagesPadding)
                    }
                    BudgetListEmptyStateSection(message: "No planned expenses in this period.") {
                        addActionButton(title: "Add Planned Expense", action: onAddTapped)
                    }
                }
                .refreshable { onTotalsChanged() }
                .styledList()
                .applyListHorizontalPadding(capabilities, layoutContext: layoutContext)
                .budgetListBottomInset(layoutContext: layoutContext)
            } else {
                // MARK: Real List for native swipe
                List {
                    if let header {
                        headerListRow(header, applyDefaultInsets: !headerManagesPadding)
                    }
                    listRows(items: items)
                }
                .refreshable { onTotalsChanged() }
                .styledList()
                .applyListHorizontalPadding(capabilities, layoutContext: layoutContext)
                .budgetListBottomInset(layoutContext: layoutContext)
            }
        }
        .sheet(item: $editingItem) { expense in
            AddPlannedExpenseView(
                plannedExpenseID: expense.objectID,
                preselectedBudgetID: expense.budget?.objectID,
                onSaved: { onTotalsChanged() }
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Expense?", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                deletePlanned(item)
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: { _ in
            Text("This will remove the planned expense.")
        }
    }

    // MARK: Local: Add action button with OS-aware styling
    @ViewBuilder
    private func addActionButton(title: String, action: @escaping () -> Void) -> some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
                Button(action: action) {
                    budgetDetailsCTAButtonLabel(title)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.glass)
                .tint(themeManager.selectedTheme.resolvedTint)
            } else {
                Button(action: action) {
                    budgetDetailsCTAButtonLabel(title)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func listRows(items: [PlannedExpense]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.objectID) { pair in
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                    // Category color indicator, matching Variable expenses
                    Circle()
                        .fill(Color(hex: pair.element.expenseCategory?.color ?? "#999999") ?? .secondary)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.element.descriptionText ?? "Untitled")
                            .font(.title3.weight(.semibold))
                        if let name = pair.element.expenseCategory?.name {
                            Text(name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text("Planned:")
                                .font(.footnote.weight(.bold))
                            Text(CurrencyFormatterHelper.string(for: pair.element.plannedAmount))
                        }
                        HStack(spacing: DS.Spacing.xs) {
                            Text("Actual:")
                                .font(.footnote.weight(.bold))
                            Text(CurrencyFormatterHelper.string(for: pair.element.actualAmount))
                        }
                        Text(Self.mediumDate(pair.element.transactionDate ?? .distantPast))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(
                listHorizontalInsets.edgeInsets(
                    top: pair.offset == 0 ? 4 : 12,
                    bottom: 12
                )
            )
            .ub_preOS26ListRowBackground(themeManager.selectedTheme.background)
            .contentShape(Rectangle())
            .unifiedSwipeActions(
                UnifiedSwipeConfig(allowsFullSwipeToDelete: false),
                onEdit: { editingItem = pair.element },
                onDelete: {
                    if confirmBeforeDelete {
                        itemToDelete = pair.element
                        showDeleteAlert = true
                    } else {
                        deletePlanned(pair.element)
                    }
                }
            )
        }
        .onDelete { indexSet in
            let itemsToDelete = indexSet.compactMap { idx in items.indices.contains(idx) ? items[idx] : nil }
            if confirmBeforeDelete, let first = itemsToDelete.first {
                itemToDelete = first
                showDeleteAlert = true
            } else {
                itemsToDelete.forEach(deletePlanned(_:))
            }
        }
    }

    // Header row used inside the List. Hide separator and remove extra bottom inset.
    @ViewBuilder
    private func headerListRow(_ header: AnyView, applyDefaultInsets: Bool = true) -> some View {
        header
            .padding(.bottom, applyDefaultInsets ? 0 : BudgetListLayoutMetrics.headerToRowsPadding)
            .listRowInsets(
                applyDefaultInsets
                    ? listHorizontalInsets.edgeInsets()
                    : EdgeInsets()
            )
            .listRowSeparator(.hidden)
            .ub_preOS26ListRowBackground(themeManager.selectedTheme.background)
    }

    @ViewBuilder
    private func headerSection(_ header: AnyView, applyDefaultInsets: Bool = true) -> some View {
        Section { headerListRow(header, applyDefaultInsets: applyDefaultInsets) }
            .ifAvailableContentMarginsZero()
    }

    // MARK: Sorting applied after fetch to honor user choice
    private func sorted(_ arr: FetchedResults<PlannedExpense>) -> [PlannedExpense] {
        var items = Array(arr)
        switch sort {
        case .titleAZ:
            items.sort { ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending }
        case .amountLowHigh:
            items.sort { $0.plannedAmount < $1.plannedAmount }
        case .amountHighLow:
            items.sort { $0.plannedAmount > $1.plannedAmount }
        case .dateOldNew:
            items.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            items.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return items
    }

    // MARK: Inclusive day bounds
    private static func clamp(_ range: ClosedRange<Date>) -> (Date, Date) {
        let cal = Calendar.current
        let s = cal.startOfDay(for: range.lowerBound)
        let e = cal.date(byAdding: DateComponents(day: 1, second: -1),
                         to: cal.startOfDay(for: range.upperBound)) ?? range.upperBound
        return (s, e)
    }

    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    // MARK: Delete helper
    /// Deletes a planned expense using the `PlannedExpenseService`. This ensures any
    /// additional business logic (such as cascading template children) runs
    /// consistently. The deletion is wrapped in an animation and followed by
    /// refreshing totals. Errors are logged and rolled back on failure.
    private func deletePlanned(_ item: PlannedExpense) {
        withAnimation {
            // Step 1: Log that deletion was triggered (verbose only).
            if AppLog.isVerbose {
                AppLog.ui.debug("deletePlanned called for: \(item.descriptionText ?? "<no description>")")
            }
            do {
                try PlannedExpenseService.shared.delete(item)
                // Defer the totals refresh to the next run loop. Updating the view model
                // immediately inside the delete animation can cause extra refreshes. This
                // async dispatch schedules the update after the current cycle completes.
                DispatchQueue.main.async {
                    onTotalsChanged()
                }
            } catch {
                AppLog.ui.error("Failed to delete planned expense: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - Shared empty list section helper
private struct BudgetListRowContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let sanitizedLayoutContext: ResponsiveLayoutContext? =
            layoutContext.containerSize.width > 0 ? layoutContext : nil
        let horizontalInsets = BudgetListHorizontalPaddingMetrics.resolvedInsets(
            for: capabilities,
            layoutContext: sanitizedLayoutContext
        )

        content
            .padding(.leading, horizontalInsets.leading)
            .padding(.trailing, horizontalInsets.trailing)
            .listRowBackground(Color.clear)
            .ub_preOS26ListRowBackground(themeManager.selectedTheme.background)
    }
}

private struct BudgetListEmptyStateSection<Button: View>: View {
    let message: String
    private let buttonBuilder: () -> Button

    init(message: String, @ViewBuilder button: @escaping () -> Button) {
        self.message = message
        self.buttonBuilder = button
    }

    var body: some View {
        Section {
            BudgetListRowContainer {
                VStack(spacing: DS.Spacing.m) {
                    buttonBuilder()
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .padding(.vertical, DS.Spacing.l)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
        }
        .ifAvailableContentMarginsZero()
    }
}

// MARK: - VariableListFR (List-backed; swipe enabled)
private struct VariableListFR: View {
    @FetchRequest private var rows: FetchedResults<UnplannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    private let attachedCards: [Card]
    private let onAddTapped: () -> Void
    private let onTotalsChanged: () -> Void
    private let header: AnyView?
    private let headerManagesPadding: Bool
    @State private var editingItem: UnplannedExpense?
    @State private var itemToDelete: UnplannedExpense?
    @State private var showDeleteAlert = false

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    private var layoutContextForInsets: ResponsiveLayoutContext? {
        layoutContext.containerSize.width > 0 ? layoutContext : nil
    }

    private var listHorizontalInsets: BudgetListHorizontalPaddingMetrics.Insets {
        BudgetListHorizontalPaddingMetrics.resolvedInsets(
            for: capabilities,
            layoutContext: layoutContextForInsets
        )
    }

    init(
        attachedCards: [Card],
        startDate: Date,
        endDate: Date,
        sort: BudgetDetailsViewModel.SortOption,
        onAddTapped: @escaping () -> Void,
        onTotalsChanged: @escaping () -> Void,
        header: AnyView? = nil,
        headerManagesPadding: Bool = false
    ) {
        self.sort = sort
        self.attachedCards = attachedCards
        self.onAddTapped = onAddTapped
        self.onTotalsChanged = onTotalsChanged
        self.header = header
        self.headerManagesPadding = headerManagesPadding

        let (s, e) = Self.clamp(startDate...endDate)
        let req: NSFetchRequest<UnplannedExpense> = NSFetchRequest(entityName: "UnplannedExpense")

        if attachedCards.isEmpty {
            req.predicate = NSPredicate(value: false)
        } else {
            req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "card IN %@", attachedCards),
                NSPredicate(format: "transactionDate >= %@ AND transactionDate <= %@", s as NSDate, e as NSDate)
            ])
        }

        req.sortDescriptors = [
            NSSortDescriptor(key: "transactionDate", ascending: false),
            NSSortDescriptor(key: "descriptionText", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        _rows = FetchRequest(fetchRequest: req, animation: .default)
    }

    var body: some View {
        // Compute the sorted array once outside of the List to avoid unintended
        // recomputations during the list diffing and to enable a straightforward
        // isEmpty check.
        let items = sorted(rows)
        Group {
            if items.isEmpty {
                // MARK: Compact empty state (single Add button)
                List {
                    if let header {
                        headerSection(header, applyDefaultInsets: !headerManagesPadding)
                    }
                    BudgetListEmptyStateSection(message: "No variable expenses in this period.") {
                        addActionButton(title: "Add Variable Expense", action: onAddTapped)
                    }
                }
                .refreshable { onTotalsChanged() }
                .styledList()
                .applyListHorizontalPadding(capabilities, layoutContext: layoutContext)
                .budgetListBottomInset(layoutContext: layoutContext)
            } else {
                // MARK: Real List for native swipe
                List {
                    if let header {
                        headerListRow(header, applyDefaultInsets: !headerManagesPadding)
                    }
                    listRows(items: items)
                }
                .refreshable { onTotalsChanged() }
                .styledList()
                .applyListHorizontalPadding(capabilities, layoutContext: layoutContext)
                .budgetListBottomInset(layoutContext: layoutContext)
            }
        }
        .sheet(item: $editingItem) { expense in
            AddUnplannedExpenseView(
                unplannedExpenseID: expense.objectID,
                allowedCardIDs: Set(attachedCards.map { $0.objectID }),
                initialDate: expense.transactionDate,
                onSaved: { onTotalsChanged() }
            )
            .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Expense?", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                deleteUnplanned(item)
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: { _ in
            Text("This will remove the expense.")
        }
    }

    // MARK: Local: Add action button with OS-aware styling
    @ViewBuilder
    private func addActionButton(title: String, action: @escaping () -> Void) -> some View {
        GlassCapsuleContainer(horizontalPadding: DS.Spacing.s, verticalPadding: DS.Spacing.s, alignment: .center) {
            Button(action: action) {
                budgetDetailsCTAButtonLabel(title)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func listRows(items: [UnplannedExpense]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.objectID) { pair in
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                    Circle()
                        .fill(Color(hex: pair.element.expenseCategory?.color ?? "#999999") ?? .secondary)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading) {
                        Text(pair.element.descriptionText ?? "Untitled")
                            .font(.title3.weight(.semibold))
                        if let name = pair.element.expenseCategory?.name {
                            Text(name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(CurrencyFormatterHelper.string(for: pair.element.amount))
                        Text(Self.mediumDate(pair.element.transactionDate ?? .distantPast))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            .listRowInsets(
                listHorizontalInsets.edgeInsets(
                    top: pair.offset == 0 ? 4 : 12,
                    bottom: 12
                )
            )
            .ub_preOS26ListRowBackground(themeManager.selectedTheme.background)
            .contentShape(Rectangle())
            .unifiedSwipeActions(
                UnifiedSwipeConfig(allowsFullSwipeToDelete: false),
                onEdit: { editingItem = pair.element },
                onDelete: {
                    if confirmBeforeDelete {
                        itemToDelete = pair.element
                        showDeleteAlert = true
                    } else {
                        deleteUnplanned(pair.element)
                    }
                }
            )
        }
        .onDelete { indexSet in
            let itemsToDelete = indexSet.compactMap { idx in items.indices.contains(idx) ? items[idx] : nil }
            if confirmBeforeDelete, let first = itemsToDelete.first {
                itemToDelete = first
                showDeleteAlert = true
            } else {
                itemsToDelete.forEach(deleteUnplanned(_:))
            }
        }
    }

    // Top header rendered as a normal list row (not a Section header) to keep
    // primary text colors and full-width layout.
    @ViewBuilder
    private func headerListRow(_ header: AnyView, applyDefaultInsets: Bool = true) -> some View {
        header
            .padding(.bottom, applyDefaultInsets ? 0 : BudgetListLayoutMetrics.headerToRowsPadding)
            .listRowInsets(
                applyDefaultInsets
                    ? listHorizontalInsets.edgeInsets()
                    : EdgeInsets()
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func headerSection(_ header: AnyView, applyDefaultInsets: Bool = true) -> some View {
        Section {
            headerListRow(header, applyDefaultInsets: applyDefaultInsets)
        }
        .ifAvailableContentMarginsZero()
    }

    // MARK: Sorting
    private func sorted(_ arr: FetchedResults<UnplannedExpense>) -> [UnplannedExpense] {
        var items = Array(arr)
        switch sort {
        case .titleAZ:
            items.sort { ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending }
        case .amountLowHigh:
            items.sort { $0.amount < $1.amount }
        case .amountHighLow:
            items.sort { $0.amount > $1.amount }
        case .dateOldNew:
            items.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            items.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return items
    }

    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    // MARK: Inclusive day bounds
    private static func clamp(_ range: ClosedRange<Date>) -> (Date, Date) {
        let cal = Calendar.current
        let s = cal.startOfDay(for: range.lowerBound)
        let e = cal.date(byAdding: DateComponents(day: 1, second: -1),
                         to: cal.startOfDay(for: range.upperBound)) ?? range.upperBound
        return (s, e)
    }

    // MARK: Delete helper
    /// Deletes a variable (unplanned) expense. We delegate to the
    /// `UnplannedExpenseService` so that any children are cascaded
    /// appropriately and other invariants (e.g. recurrence handling) are
    /// maintained. On success totals are refreshed; on failure the
    /// context is rolled back and the error is logged.
    private func deleteUnplanned(_ item: UnplannedExpense) {
        withAnimation {
            let service = UnplannedExpenseService()
            do {
                // Step 1: Log that deletion was triggered for debugging purposes.
                if AppLog.isVerbose {
                    AppLog.ui.debug("deleteUnplanned called for: \(item.descriptionText ?? "<no description>")")
                }
                try service.delete(item, cascadeChildren: true)
                // Defer totals refresh to the next run loop to avoid view update loops.
                DispatchQueue.main.async {
                    onTotalsChanged()
                }
            } catch {
                AppLog.ui.error("Failed to delete unplanned expense: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - Shared CTA Helpers

@ViewBuilder
private func budgetDetailsCTAButtonLabel(_ title: String) -> some View {
    Label(title, systemImage: "plus")
        .labelStyle(.titleAndIcon)
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
}

// MARK: - Shared List Styling Helpers
private extension View {
    /// Applies the plain list style and hides default backgrounds where supported; keeps your custom look.
    @ViewBuilder
    func styledList() -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            self
                .ub_listStyleLiquidAware()
#if os(iOS)
                .scrollIndicators(.hidden)
                .background(UBScrollViewInsetAdjustmentDisabler())
#endif
        } else {
            self.ub_listStyleLiquidAware()
        }
    }

    @ViewBuilder
    func applyListHorizontalPadding(
        _ capabilities: PlatformCapabilities,
        layoutContext: ResponsiveLayoutContext? = nil
    ) -> some View {
        Group {
            if let insets = resolveBudgetListPadding(
                for: capabilities,
                layoutContext: layoutContext
            ).insets {
                self
                    .padding(.leading, insets.leading)
                    .padding(.trailing, insets.trailing)
            } else {
                self
            }
        }
    }

    @ViewBuilder
    func budgetListBottomInset(layoutContext: ResponsiveLayoutContext) -> some View {
        #if os(iOS)
        #if targetEnvironment(macCatalyst)
        self
        #else
        let inset = BudgetListBottomInsetMetrics.bottomInset(for: layoutContext)
        if inset > 0 {
            self.safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: inset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            self
        }
        #endif
        #else
        self
        #endif
    }

    @ViewBuilder
    func ifAvailableContentMarginsZero() -> some View {
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            self.contentMargins(.vertical, 0)
        } else {
            self
        }
    }
}

// MARK: - List Padding Resolution

private struct BudgetListPaddingResolution {
    let sanitizedLayoutContext: ResponsiveLayoutContext?
    let insets: BudgetListHorizontalPaddingMetrics.Insets?

    static let none = BudgetListPaddingResolution(
        sanitizedLayoutContext: nil,
        insets: nil
    )
}

private func resolveBudgetListPadding(
    for capabilities: PlatformCapabilities,
    layoutContext: ResponsiveLayoutContext?
) -> BudgetListPaddingResolution {
    guard capabilities.supportsOS26Translucency == false else {
        return .none
    }

    let sanitizedLayoutContext = sanitizeLayoutContextForBudgetListPadding(layoutContext)

    let resolvedInsets = BudgetListHorizontalPaddingMetrics.resolvedInsets(
        for: capabilities,
        layoutContext: sanitizedLayoutContext
    )

    return BudgetListPaddingResolution(
        sanitizedLayoutContext: sanitizedLayoutContext,
        insets: resolvedInsets
    )
}

private func sanitizeLayoutContextForBudgetListPadding(
    _ layoutContext: ResponsiveLayoutContext?
) -> ResponsiveLayoutContext? {
    guard let layoutContext, layoutContext.containerSize.width > 0 else {
        return nil
    }
    return layoutContext
}

private enum BudgetListLayoutMetrics {
    static let headerToRowsPadding: CGFloat = DS.Spacing.s
}

private enum BudgetListHorizontalPaddingMetrics {
    static let wideLayoutMinimumWidth: CGFloat = 600

    struct Insets {
        let leading: CGFloat
        let trailing: CGFloat

        var symmetricInset: CGFloat {
            max(leading, trailing)
        }

        func edgeInsets(top: CGFloat = 0, bottom: CGFloat = 0) -> EdgeInsets {
            EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        }
    }

    static func resolvedInsets(
        for capabilities: PlatformCapabilities,
        layoutContext: ResponsiveLayoutContext?
    ) -> Insets {
        if capabilities.supportsOS26Translucency {
            return Insets(
                leading: RootTabHeaderLayout.defaultHorizontalPadding,
                trailing: RootTabHeaderLayout.defaultHorizontalPadding
            )
        }

        guard let layoutContext, layoutContext.containerSize.width > 0 else {
            return Insets(
                leading: RootTabHeaderLayout.defaultHorizontalPadding,
                trailing: RootTabHeaderLayout.defaultHorizontalPadding
            )
        }

        if layoutContext.containerSize.width >= wideLayoutMinimumWidth {
            return Insets(
                leading: RootTabHeaderLayout.defaultHorizontalPadding,
                trailing: RootTabHeaderLayout.defaultHorizontalPadding
            )
        }

        let safeArea = layoutContext.safeArea
        if safeArea.hasNonZeroInsets {
            return Insets(leading: safeArea.leading, trailing: safeArea.trailing)
        }

        return Insets(leading: 0, trailing: 0)
    }
}

private enum BudgetListBottomInsetMetrics {
    #if os(iOS)
    #if targetEnvironment(macCatalyst)
    static func bottomInset(for layoutContext: ResponsiveLayoutContext) -> CGFloat { 0 }
    #else
    private static let compactTabBarHeight: CGFloat = 49
    private static let regularTabBarHeight: CGFloat = 49

    static func bottomInset(for layoutContext: ResponsiveLayoutContext) -> CGFloat {
        let safeArea = layoutContext.safeArea.bottom
        let sizeClass = layoutContext.horizontalSizeClass ?? .compact
        let tabBarHeight = sizeClass == .regular ? regularTabBarHeight : compactTabBarHeight
        if safeArea >= tabBarHeight - 1 {
            return safeArea
        } else {
            return safeArea + tabBarHeight
        }
    }
    #endif
    #else
    static func bottomInset(for layoutContext: ResponsiveLayoutContext) -> CGFloat { 0 }
    #endif
}

// MARK: - Currency Formatting Helper
enum CurrencyFormatterHelper {
    private static let fallbackCurrencyCode = "USD"

    static func string(for amount: Double) -> String {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            return amount.formatted(.currency(code: currencyCode))
        } else {
            return legacyString(for: amount)
        }
    }

    private static var currencyCode: String {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            return Locale.current.currency?.identifier ?? fallbackCurrencyCode
        } else {
            return Locale.current.currencyCode ?? fallbackCurrencyCode
        }
    }

    private static func legacyString(for amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: amount as NSNumber) ?? String(format: "%.2f", amount)
    }
}
