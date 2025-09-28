//
//  HomeView.swift
//  SoFar
//
//  Displays month header and, when a budget exists for the selected month,
//  shows the full BudgetDetailsView inline. Otherwise an empty state encourages
//  creating a budget.
//
//  Empty-state centering:
//  - We place a ZStack as the content container *below the header*.
//  - When there are no budgets, we show UBEmptyState inside that ZStack.
//  - UBEmptyState uses maxWidth/maxHeight = .infinity, so it centers itself
//    within the ZStack's available area (i.e., the viewport minus the header).
//  - When budgets exist, we show BudgetDetailsView in the same ZStack,
//    so there’s no layout jump switching between states.
//

import SwiftUI
import CoreData
import Foundation
import Combine

// MARK: - HomeView
struct HomeView: View {

    // MARK: State & ViewModel
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue) private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue
    private var budgetPeriod: BudgetPeriod { BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly }
    @State private var selectedSegment: BudgetDetailsViewModel.Segment = .planned
    @State private var homeSort: BudgetDetailsViewModel.SortOption = .dateNewOld

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false
    @State private var editingBudget: BudgetSummary?
    @State private var isShowingAddExpenseMenu: Bool = false
    @State private var addMenuTargetBudgetID: NSManagedObjectID?
    // Direct add flows when no budget is active
    @State private var isPresentingAddPlannedFromHome: Bool = false
    @State private var isPresentingAddVariableFromHome: Bool = false
    // Manage sheets
    @State private var isPresentingManageCards: Bool = false
    @State private var isPresentingManagePresets: Bool = false

    private var headerControlDimension: CGFloat {
        RootHeaderActionMetrics.dimension(for: capabilities)
    }

    // MARK: Header Layout
    @State private var matchedHeaderControlWidth: CGFloat?
    @State private var cachedHeaderControlWidth: CGFloat?
    @State private var headerActionPillIntrinsicWidth: CGFloat?
    @State private var periodNavigationIntrinsicWidth: CGFloat?
    // Tracks the last measured header control width to avoid micro-update loops
    // that can cause continuous layout thrash and block interactions.
    @State private var lastMeasuredHeaderControlPrefWidth: CGFloat?
    // Track measured height of the empty-state content to size the bottom filler precisely.
    @State private var emptyStateMeasuredHeight: CGFloat = 0
    // Reset header width matching on trait changes (e.g., rotation) to avoid
    // stale measurements forcing an oversized minWidth when returning from
    // landscape → portrait. This keeps the period navigation rendering stable.
#if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

    // MARK: Body
    var body: some View {
        // Sticky header; conditionally wrap content in a ScrollView.
        // - When a budget exists, do NOT wrap (BudgetDetailsView has Lists).
        // - When empty/no budget, allow the content to manage its own scrolling.
        // Manage scroll per-state; keep header sticky without an outer ScrollView.
        RootTabPageScaffold(
            scrollBehavior: .auto,
            spacing: DS.Spacing.s,
            wrapsContentInScrollView: false
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
        .confirmationDialog(
            "Add",
            isPresented: $isShowingAddExpenseMenu,
            titleVisibility: .visible
        ) {
            Button("Add Planned Expense") {
                triggerAddExpenseFromMenu(.budgetDetailsRequestAddPlannedExpense)
            }
            Button("Add Variable Expense") {
                triggerAddExpenseFromMenu(.budgetDetailsRequestAddVariableExpense)
            }
        }
        .ub_onChange(of: isShowingAddExpenseMenu) { newValue in
            if !newValue {
                addMenuTargetBudgetID = nil
            }
        }
        // Clear cached/matched widths when key traits change so controls can
        // re-measure for the new size class/orientation.
#if os(iOS)
        .ub_onChange(of: horizontalSizeClass) { _ in resetHeaderWidthMatching() }
        .ub_onChange(of: verticalSizeClass) { _ in resetHeaderWidthMatching() }
#endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: headerSectionSpacing) {
            RootViewTopPlanes(
                title: "Home",
                topPaddingStyle: .navigationBarAligned,
                trailingPlacement: .right
            ) {
                headerActions
            }

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

    @ViewBuilder
    private var headerActions: some View {
        let headerSummary = primarySummary
        let hasBudget = hasActiveBudget
        let showsContextSummary = hasBudget && headerSummary != nil && showsHeaderSummary
        // Move the period navigation into BudgetDetailsView when a budget is
        // loaded so it scrolls with content. Keep it in the Home header only
        // when no budget exists for the selected period.
        // Period navigation should render in the content area for both states
        // to match the prior design. Keep it out of the sticky header.
        let showsPeriodNavigation = false
        let matchedControlWidth = hasBudget
            ? matchedHeaderControlWidth
            : cachedHeaderControlWidth

        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            Group {
                switch headerSummary {
                case .some(let summary):
                    // Always three standalone glass buttons when a budget exists.
                    HStack(spacing: DS.Spacing.s) {
                        calendarMenuButton()
                        addExpenseIconButton(for: summary.id)
                        optionsMenuButton(summary: summary)
                    }
                case .none:
                    // Show calendar, Add Expense (+), and budget options (…)
                    HStack(spacing: DS.Spacing.s) {
                        calendarMenuButton()
                        addExpenseNoBudgetIconButton()
                        optionsMenuButton()
                    }
                }
            }

            if showsContextSummary || showsPeriodNavigation {
                if showsContextSummary, let summary = headerSummary {
                    HStack(spacing: DS.Spacing.s) {
                        HomeHeaderContextSummary(summary: summary)
                            .layoutPriority(0)

                        Spacer(minLength: 0)

                        if showsPeriodNavigation {
                            periodNavigationControl(style: .glassIfAvailable)
                                .layoutPriority(1)
                                .homeHeaderMinMatchedWidth(
                                    intrinsicWidth: $periodNavigationIntrinsicWidth,
                                    matchedWidth: matchedControlWidth
                                )
                        }
                    }
                } else if showsPeriodNavigation {
                    periodNavigationControl(style: .glassIfAvailable)
                        .layoutPriority(1)
                        .homeHeaderMinMatchedWidth(
                            intrinsicWidth: $periodNavigationIntrinsicWidth,
                            matchedWidth: matchedControlWidth
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onPreferenceChange(HomeHeaderControlWidthKey.self) { width in
            // Guard against tiny oscillations (e.g., sub‑pixel rounding) that
            // can create an endless measure→set→measure loop.
            let newWidth = (width * 2).rounded() / 2 // quantize to 0.5pt
            guard newWidth > 0 else { return }

            let previous = lastMeasuredHeaderControlPrefWidth ?? 0
            let tolerance: CGFloat = 0.5
            guard abs(newWidth - previous) > tolerance else { return }

            lastMeasuredHeaderControlPrefWidth = newWidth

            if hasBudget {
                matchedHeaderControlWidth = newWidth
            }
            cachedHeaderControlWidth = newWidth
        }
        .ub_onChange(of: hasBudget) { newValue in
            guard !newValue else { return }
            matchedHeaderControlWidth = nil
            headerActionPillIntrinsicWidth = nil
            periodNavigationIntrinsicWidth = nil
        }
    }

    private func resetHeaderWidthMatching() {
        matchedHeaderControlWidth = nil
        cachedHeaderControlWidth = nil
        headerActionPillIntrinsicWidth = nil
        periodNavigationIntrinsicWidth = nil
        lastMeasuredHeaderControlPrefWidth = nil
    }

    @ViewBuilder
    private var periodPickerControl: some View {
        Menu {
            ForEach(BudgetPeriod.selectableCases) { period in
                Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
            }
        } label: {
            RootHeaderControlIcon(systemImage: "calendar")
                .accessibilityLabel(budgetPeriod.displayName)
                .frame(
                    width: headerControlDimension,
                    height: headerControlDimension,
                    alignment: .center
                )
        }
#if os(macOS)
        .menuStyle(.borderlessButton)
#endif
        .modifier(HideMenuIndicatorIfPossible())
    }

    private var trailingActionControl: AnyView? {
        switch vm.state {
        case .empty:
            return AnyView(emptyStateTrailingControls)
        case .loaded(let summaries):
            if let first = summaries.first {
                return AnyView(trailingControls(for: first))
            } else {
                return AnyView(emptyStateTrailingControls)
            }
        default:
            return nil
        }
    }

    private func trailingControls(for summary: BudgetSummary) -> some View {
        let dimension = headerControlDimension
        return HStack(spacing: 0) {
            addExpenseButton(for: summary.id)
            Rectangle()
                .fill(RootHeaderLegacyGlass.dividerColor(for: themeManager.selectedTheme))
                .frame(width: 1, height: dimension)
                .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
                .allowsHitTesting(false)
            budgetActionMenu(summary: summary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .rootHeaderActionColumns(2)
    }

    @ViewBuilder
    private func addExpenseButton(for budgetID: NSManagedObjectID) -> some View {
        let dimension = headerControlDimension
        Group {
#if os(iOS)
            Button {
                presentAddExpenseMenu(for: budgetID)
            } label: {
                RootHeaderControlIcon(systemImage: "plus")
            }
            .buttonStyle(RootHeaderActionButtonStyle())
#else
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
            .menuStyle(.borderlessButton)
#endif
        }
        .frame(minWidth: dimension, maxWidth: .infinity, minHeight: dimension)
        .contentShape(Rectangle())
        .accessibilityLabel("Add Expense")
    }

    private var emptyStateTrailingControls: some View { EmptyView() }

    private func budgetActionMenu(summary: BudgetSummary?) -> some View {
        Menu {
            if let summary {
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
            } else {
                Button {
                    isPresentingAddBudget = true
                } label: {
                    Label("Create Budget", systemImage: "plus")
                }
            }
        } label: {
            RootHeaderControlIcon(systemImage: "ellipsis", symbolVariants: SymbolVariants.none)
                // Keep overflow menu glyph horizontal per header controls design.
                .accessibilityLabel(summary == nil ? "Budget Options" : "Budget Actions")
        }
        .modifier(HideMenuIndicatorIfPossible())
#if os(macOS)
        .menuStyle(.borderlessButton)
#endif
        .frame(
            minWidth: headerControlDimension,
            maxWidth: .infinity,
            minHeight: headerControlDimension
        )
    }

    // MARK: Empty-state: Create budget (+)
    private func addBudgetButton() -> some View {
        let dimension = headerControlDimension
        return Button {
            isPresentingAddBudget = true
        } label: {
            RootHeaderControlIcon(systemImage: "plus")
        }
        .buttonStyle(RootHeaderActionButtonStyle())
        .frame(minWidth: dimension, maxWidth: .infinity, minHeight: dimension)
        .contentShape(Rectangle())
        .accessibilityLabel("Create Budget")
    }

    // MARK: New: Standalone glass buttons for empty state header
    private func calendarMenuButton() -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
            Menu {
                ForEach(BudgetPeriod.selectableCases) { period in
                    Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
                }
            } label: {
                RootHeaderControlIcon(systemImage: "calendar")
                    .accessibilityLabel(budgetPeriod.displayName)
            }
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
            .modifier(HideMenuIndicatorIfPossible())
        }
    }

    private func addBudgetIconButton() -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
            Button {
                isPresentingAddBudget = true
            } label: {
                RootHeaderControlIcon(systemImage: "plus")
            }
            .buttonStyle(RootHeaderActionButtonStyle())
            .accessibilityLabel("Create Budget")
        }
    }

    private func optionsMenuButton() -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
            Menu {
                Button {
                    isPresentingAddBudget = true
                } label: {
                    Label("Create Budget", systemImage: "plus")
                }
            } label: {
                RootHeaderControlIcon(systemImage: "ellipsis", symbolVariants: SymbolVariants.none)
                    .accessibilityLabel("Budget Options")
            }
            .modifier(HideMenuIndicatorIfPossible())
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
    }

    // Add Expense button when no budget is active — presents direct add flows.
    private func addExpenseNoBudgetIconButton() -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
            Menu {
                Button("Add Planned Expense") { isPresentingAddPlannedFromHome = true }
                Button("Add Variable Expense") { isPresentingAddVariableFromHome = true }
            } label: {
                RootHeaderControlIcon(systemImage: "plus")
                    .accessibilityLabel("Add Expense")
            }
            .modifier(HideMenuIndicatorIfPossible())
#if os(macOS)
            .menuStyle(.borderlessButton)
#endif
        }
    }

    private func addExpenseIconButton(for budgetID: NSManagedObjectID) -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
            Group {
            #if os(iOS)
                Button { presentAddExpenseMenu(for: budgetID) } label: {
                    RootHeaderControlIcon(systemImage: "plus")
                }
                .buttonStyle(RootHeaderActionButtonStyle())
                .accessibilityLabel("Add Expense")
            #else
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
                .menuStyle(.borderlessButton)
            #endif
            }
        }
    }

    private func optionsMenuButton(summary: BudgetSummary) -> some View {
        let d = RootHeaderActionMetrics.dimension(for: capabilities)

        return RootHeaderGlassControl(width: d, sizing: .icon) {
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
                    .accessibilityLabel("Budget Actions")
            }
            .modifier(HideMenuIndicatorIfPossible())
        #if os(macOS)
            .menuStyle(.borderlessButton)
        #endif
        }
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
                emptyPeriodShell(proxy: proxy)

            case .loaded(let summaries):
                if let first = summaries.first {
#if os(macOS)
                    BudgetDetailsView(
                        budgetObjectID: first.id,
                        periodNavigation: .init(
                            title: title(for: vm.selectedDate),
                            onAdjust: { delta in vm.adjustSelectedPeriod(by: delta) }
                        ),
                        displaysBudgetTitle: false,
                        showsIncomeSavingsGrid: false,
                        onSegmentChange: { newSegment in
                            self.selectedSegment = newSegment
                        }
                    )
                    .id(first.id)
                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#else
                    BudgetDetailsView(
                        budgetObjectID: first.id,
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
                    .id(first.id)
                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
                } else {
                    emptyPeriodShell(proxy: proxy)
                }
            }
        }
    }

    // MARK: Empty Period Shell (replaces generic empty state)
    @ViewBuilder
    private func emptyPeriodShell(proxy: RootTabPageProxy) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                // Period navigation in content (original position)
                periodNavigationControl(style: .glassIfAvailable)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Section header + running total for the current segment
                HomeSegmentTotalsRowView(segment: selectedSegment, total: 0)

                // Segment control in content
                HomeGlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s) {
                    Picker("", selection: $selectedSegment) {
                        Text("Planned Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.planned)
                        Text("Variable Expenses").segmentedFill().tag(BudgetDetailsViewModel.Segment.variable)
                    }
                    .pickerStyle(.segmented)
                    .equalWidthSegments()
                    .frame(maxWidth: .infinity)
#if os(macOS)
                    .controlSize(.large)
                    .tint(themeManager.selectedTheme.glassPalette.accent)
#endif
                }

                // Filter bar (sort options)
                HomeGlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s, alignment: .center) {
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
#if os(macOS)
                    .controlSize(.large)
                    .tint(themeManager.selectedTheme.glassPalette.accent)
#endif
                }

                // Always-offer Add button when no budget exists so users can
                // quickly create an expense for this period.
                HomeGlassCapsuleContainer(horizontalPadding: DS.Spacing.l, verticalPadding: DS.Spacing.s, alignment: .center) {
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
        .ub_ignoreSafeArea(edges: .bottom)
        .ub_hideScrollIndicators()
    }

    private var headerSectionSpacing: CGFloat {
        let hasPrimarySummary = primarySummary != nil
#if os(macOS)
        return hasPrimarySummary ? 0 : DS.Spacing.xs / 2
#else
        return hasPrimarySummary ? DS.Spacing.xs / 2 : DS.Spacing.xs / 2
#endif
    }

    private func periodNavigationControl(style: PeriodNavigationControl.Style) -> PeriodNavigationControl {
        PeriodNavigationControl(
            title: title(for: vm.selectedDate),
            style: style,
            onPrevious: { vm.adjustSelectedPeriod(by: -1) },
            onNext: { vm.adjustSelectedPeriod(by: +1) }
        )
    }

    private var showsHeaderSummary: Bool {
#if os(macOS)
        return false
#elseif os(iOS)
        // Keep the Home header compact on iOS in all size classes to avoid
        // duplication next to the period navigation and to reduce height in
        // landscape.
        return false
#else
        return false
#endif
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

    private var hasActiveBudget: Bool {
        if case .loaded(let summaries) = vm.state {
            return !summaries.isEmpty
        }
        return false
    }

    private var emptyStateMessage: String {
        "No budget found for \(title(for: vm.selectedDate)). Use Create a budget to set one up for this period."
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

    private func triggerAddExpenseFromMenu(_ notificationName: Notification.Name) {
        guard let budgetID = activeAddExpenseTarget else { return }
        isShowingAddExpenseMenu = false
        triggerAddExpense(notificationName, budgetID: budgetID)
    }

    private func presentAddExpenseMenu(for budgetID: NSManagedObjectID) {
        addMenuTargetBudgetID = budgetID
        isShowingAddExpenseMenu = true
    }

    private var activeAddExpenseTarget: NSManagedObjectID? {
        if let explicitTarget = addMenuTargetBudgetID {
            return explicitTarget
        }
        guard case let .loaded(summaries) = vm.state else { return nil }
        return summaries.first?.id
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
            if #available(iOS 16.0, macOS 13.0, *) {
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

    @available(iOS 16.0, macOS 13.0, *)
    @ViewBuilder
    private func headerRow(_ left: String, _ right: String) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { header(left) }
            trailingGridCell { header(right) }
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    @ViewBuilder
    private func valuesRow(_ leftValue: Double, _ leftColor: Color, _ rightValue: Double, _ rightColor: Color) -> some View {
        GridRow(alignment: .lastTextBaseline) {
            leadingGridCell { value(leftValue, leftColor) }
            trailingGridCell { value(rightValue, rightColor) }
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    @ViewBuilder
    private func leadingGridCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) { content(); Spacer(minLength: 0) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @available(iOS 16.0, macOS 13.0, *)
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
        if #available(iOS 15.0, macOS 12.0, *) {
            let code: String
            if #available(iOS 16.0, macOS 13.0, *) {
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
        if #available(iOS 15.0, macOS 12.0, *) {
            let code: String
            if #available(iOS 16.0, macOS 13.0, *) {
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

// MARK: - Empty shell helpers (glass capsule + segmented sizing)
private struct HomeGlassCapsuleContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let contentAlignment: Alignment

    init(
        horizontalPadding: CGFloat = DS.Spacing.l,
        verticalPadding: CGFloat = DS.Spacing.m,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.contentAlignment = alignment
    }

    var body: some View {
        let capsule = Capsule(style: .continuous)
        let decorated = content
            .frame(maxWidth: .infinity, alignment: contentAlignment)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(capsule)

        if #available(iOS 26.0, macOS 26.0, tvOS 18.0, macCatalyst 26.0, *), capabilities.supportsOS26Translucency {
            GlassEffectContainer {
                decorated
                    .glassEffect(.regular.interactive(), in: capsule)
            }
        } else {
            decorated
        }
    }
}

private extension View {
    func segmentedFill() -> some View { frame(maxWidth: .infinity) }
    func equalWidthSegments() -> some View { modifier(HomeEqualWidthSegmentsModifier()) }
}

private struct HomeEqualWidthSegmentsModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.background(HomeEqualWidthSegmentApplier())
#elseif os(macOS)
        content.background(HomeEqualWidthSegmentApplier())
#else
        content
#endif
    }
}

#if os(iOS)
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
#elseif os(macOS)
private struct HomeEqualWidthSegmentApplier: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0.0
        DispatchQueue.main.async { self.applyEqualWidthIfNeeded(from: view, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.applyEqualWidthIfNeeded(from: nsView, coordinator: context.coordinator) }
    }

    private func applyEqualWidthIfNeeded(from view: NSView, coordinator: Coordinator) {
        guard let segmented = findSegmentedControl(from: view) else {
            coordinator.reset()
            return
        }
        guard let hostingView = findHostingView(for: segmented) ?? segmented.superview else {
            coordinator.reset()
            return
        }

        configure(segmented: segmented, hostingView: hostingView, rootView: view, coordinator: coordinator)
    }

    private func configure(segmented: NSSegmentedControl, hostingView: NSView, rootView: NSView, coordinator: Coordinator) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            let count = segmented.segmentCount
            guard count > 0 else { return }
            segmented.layoutSubtreeIfNeeded()
            let totalWidth = segmented.bounds.width
            guard totalWidth > 0 else { return }
            let equalWidth = totalWidth / CGFloat(count)
            for index in 0..<count { segmented.setWidth(equalWidth, forSegment: index) }
        }

        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        coordinator.activate(&coordinator.leadingConstraint, first: segmented, second: hostingView) {
            segmented.leadingAnchor.constraint(equalTo: hostingView.leadingAnchor)
        }

        coordinator.activate(&coordinator.trailingConstraint, first: segmented, second: hostingView) {
            segmented.trailingAnchor.constraint(equalTo: hostingView.trailingAnchor)
        }

        if let container = hostingView.superview {
            coordinator.activate(&coordinator.hostingWidthConstraint, first: hostingView, second: container) {
                let constraint = hostingView.widthAnchor.constraint(equalTo: container.widthAnchor)
                constraint.priority = NSLayoutConstraint.Priority(999)
                return constraint
            }
        } else {
            coordinator.hostingWidthConstraint?.isActive = false
            coordinator.hostingWidthConstraint = nil
        }

        coordinator.rootView = rootView
        coordinator.observeBounds(of: hostingView, rootView: rootView) { [applier = self, weak coordinator] in
            guard let coordinator = coordinator, let rootView = coordinator.rootView else { return }
            applier.scheduleReapply(from: rootView, coordinator: coordinator)
        }

        segmented.invalidateIntrinsicContentSize()
    }

    private func scheduleReapply(from view: NSView, coordinator: Coordinator) {
        DispatchQueue.main.async { self.applyEqualWidthIfNeeded(from: view, coordinator: coordinator) }
    }

    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        guard let root = view.superview else { return nil }
        return searchSegmented(in: root)
    }

    private func searchSegmented(in node: NSView) -> NSSegmentedControl? {
        for sub in node.subviews {
            if let seg = sub as? NSSegmentedControl { return seg }
            if let found = searchSegmented(in: sub) { return found }
        }
        return nil
    }

    private func findHostingView(for segmented: NSView) -> NSView? {
        var current = segmented.superview
        while let candidate = current {
            if !candidate.translatesAutoresizingMaskIntoConstraints || isHostingView(candidate) {
                return candidate
            }
            current = candidate.superview
        }
        return nil
    }

    private func isHostingView(_ view: NSView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        return className.contains("NSHostingView")
    }

    final class Coordinator {
        weak var rootView: NSView?
        var leadingConstraint: NSLayoutConstraint?
        var trailingConstraint: NSLayoutConstraint?
        var hostingWidthConstraint: NSLayoutConstraint?
        private var boundsObserver: NSObjectProtocol?
        private weak var observedView: NSView?

        deinit { tearDownObservation() }

        func reset() {
            leadingConstraint?.isActive = false
            trailingConstraint?.isActive = false
            hostingWidthConstraint?.isActive = false
            leadingConstraint = nil
            trailingConstraint = nil
            hostingWidthConstraint = nil
            rootView = nil
            tearDownObservation()
        }

        func activate(
            _ storage: inout NSLayoutConstraint?,
            first expectedFirst: NSView,
            second expectedSecond: NSView,
            builder: () -> NSLayoutConstraint
        ) {
            if let existing = storage {
                if (existing.firstItem as? NSView) === expectedFirst,
                   (existing.secondItem as? NSView) === expectedSecond {
                    if existing.isActive == false { existing.isActive = true }
                    return
                }
                existing.isActive = false
            }

            let constraint = builder()
            constraint.isActive = true
            storage = constraint
        }

        func observeBounds(of hostingView: NSView, rootView: NSView, action: @escaping () -> Void) {
            if observedView !== hostingView {
                tearDownObservation()
                hostingView.postsBoundsChangedNotifications = true
                observedView = hostingView
                boundsObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: hostingView,
                    queue: nil
                ) { _ in action() }
            }

            self.rootView = rootView
        }

        private func tearDownObservation() {
            if let observer = boundsObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            boundsObserver = nil
            observedView?.postsBoundsChangedNotifications = false
            observedView = nil
        }
    }
}
#endif

// MARK: - Home Header Summary
private struct HomeHeaderContextSummary: View {
    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(primaryTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(secondaryDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryTitle: String {
        summary.budgetName
    }

    private var secondaryDetail: String {
        summary.periodString
    }
}

// MARK: - Header Control Width Matching

private struct HomeHeaderMatchedWidthModifier: ViewModifier {
    let intrinsicWidth: Binding<CGFloat?>
    let matchedWidth: CGFloat?
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        content
            .background(
                HomeHeaderControlWidthReporter(intrinsicWidth: intrinsicWidth)
            )
            .frame(width: resolvedWidth)
    }

    private var resolvedWidth: CGFloat? {
        let minimum = minimumWidth
        let intrinsic = intrinsicWidth.wrappedValue ?? 0

        if let matchedWidth, matchedWidth > 0 {
            // Allow the view to grow to its intrinsic width if it's larger than
            // the matched width to avoid truncation (e.g., long month names).
            return max(max(matchedWidth, intrinsic), minimum)
        }

        if intrinsic > 0 { return max(intrinsic, minimum) }
        return nil
    }

    private var minimumWidth: CGFloat {
        RootHeaderActionMetrics.minimumGlassWidth(for: capabilities)
    }
}

private struct HomeHeaderControlWidthReporter: View {
    let intrinsicWidth: Binding<CGFloat?>

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: HomeHeaderControlWidthKey.self, value: proxy.size.width)
                .onAppear { updateIntrinsicWidth(proxy.size.width) }
                .ub_onChange(of: proxy.size.width) { newWidth in
                    updateIntrinsicWidth(newWidth)
                }
        }
    }

    private func updateIntrinsicWidth(_ width: CGFloat) {
        let binding = intrinsicWidth
        DispatchQueue.main.async {
            let quantized = (width * 2).rounded() / 2 // 0.5pt steps
            let old = binding.wrappedValue ?? 0
            let tolerance: CGFloat = 0.5
            if abs(old - quantized) > tolerance {
                binding.wrappedValue = quantized
            }
        }
    }
}

private struct HomeHeaderControlWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func homeHeaderMatchedControlWidth(
        intrinsicWidth: Binding<CGFloat?>,
        matchedWidth: CGFloat?
    ) -> some View {
        modifier(
            HomeHeaderMatchedWidthModifier(
                intrinsicWidth: intrinsicWidth,
                matchedWidth: matchedWidth
            )
        )
    }

    /// Applies a minimum width equal to the larger of the matched width or
    /// the view's intrinsic width (never smaller than the design minimum).
    /// This allows content (e.g., a period picker) to expand as needed to
    /// avoid truncation while still aligning with the header controls.
    func homeHeaderMinMatchedWidth(
        intrinsicWidth: Binding<CGFloat?>,
        matchedWidth: CGFloat?
    ) -> some View {
        modifier(
            HomeHeaderMinWidthModifier(
                intrinsicWidth: intrinsicWidth,
                matchedWidth: matchedWidth
            )
        )
    }

    @ViewBuilder
    func applyIf<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private struct HomeHeaderMinWidthModifier: ViewModifier {
    let intrinsicWidth: Binding<CGFloat?>
    let matchedWidth: CGFloat?
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        content
            .background(
                HomeHeaderControlWidthReporter(intrinsicWidth: intrinsicWidth)
            )
            .frame(minWidth: resolvedMinWidth)
    }

    private var resolvedMinWidth: CGFloat? {
        let minimum = minimumWidth
        let intrinsic = intrinsicWidth.wrappedValue ?? 0
        let matched = matchedWidth ?? 0
        let base = max(intrinsic, matched, minimum)
        return base > 0 ? base : nil
    }

    private var minimumWidth: CGFloat {
        RootHeaderActionMetrics.minimumGlassWidth(for: capabilities)
    }
}

// MARK: - Header Action Helpers
#if os(iOS) || os(macOS)
private struct HideMenuIndicatorIfPossible: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            content.menuIndicator(.hidden)
        } else {
            content
        }
    }
}
#endif

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
