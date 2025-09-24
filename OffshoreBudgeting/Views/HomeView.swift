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
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue) private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue
    private var budgetPeriod: BudgetPeriod { BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly }
    @State private var selectedSegment: BudgetDetailsViewModel.Segment = .planned

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false
    @State private var editingBudget: BudgetSummary?
    @State private var isShowingAddExpenseMenu: Bool = false
    @State private var addMenuTargetBudgetID: NSManagedObjectID?

    // MARK: Header Layout
    @State private var matchedHeaderControlWidth: CGFloat?
    @State private var cachedHeaderControlWidth: CGFloat?
    @State private var headerActionPillIntrinsicWidth: CGFloat?
    @State private var periodNavigationIntrinsicWidth: CGFloat?

    // MARK: Body
    var body: some View {
        RootTabPageScaffold {
            headerSection
        } content: { proxy in
            contentContainer
                .rootTabContentPadding(proxy, horizontal: 0)
        }
        .ub_tabNavigationTitle("Home")
        .refreshable { await vm.refresh() }
        .task {
            CoreDataService.shared.ensureLoaded()
            vm.startIfNeeded()
        }
        // Debounce rapid change bursts (e.g., multiple saves/merges) to avoid
        // redundant refresh calls that could keep the view in a loading state.
        .onReceive(
            NotificationCenter.default
                .publisher(for: .dataStoreDidChange)
                .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        ) { _ in
            Task { await vm.refresh(debounce: true) }
        }
        .ub_onChange(of: budgetPeriodRawValue) { newValue in
            let newPeriod = BudgetPeriod(rawValue: newValue) ?? .monthly
            vm.updateBudgetPeriod(to: newPeriod)
        }

        // MARK: ADD SHEET — present new budget UI for the selected period
        .sheet(isPresented: $isPresentingAddBudget, content: makeAddBudgetView)
        .sheet(item: $editingBudget, content: makeEditBudgetView)
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
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: headerSectionSpacing) {
            RootViewTopPlanes(
                title: "Home",
                topPaddingStyle: .navigationBarAligned
            ) {
                headerActions
            }

            if let summary = primarySummary {
                HomeHeaderPrimarySummaryView(summary: summary)
                    .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        let trailing = trailingActionControl
        let headerSummary = primarySummary
        let hasBudget = hasActiveBudget
        let showsContextSummary = hasBudget && headerSummary != nil && showsHeaderSummary
        let showsStandalonePeriodNavigation = hasBudget && headerSummary != nil && !showsHeaderSummary
        let matchedControlWidth = hasBudget
            ? matchedHeaderControlWidth
            : cachedHeaderControlWidth

        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            Group {
                switch headerSummary {
                case .some:
                    if showsStandalonePeriodNavigation {
                        RootHeaderGlassPill(
                            showsDivider: trailing != nil,
                            hasTrailing: trailing != nil
                        ) {
                            periodPickerControl
                        } trailing: {
                            if let trailing {
                                trailing
                            }
                        }
                    } else {
                        RootHeaderGlassPill(
                            showsDivider: trailing != nil,
                            hasTrailing: trailing != nil
                        ) {
                            periodPickerControl
                        } trailing: {
                            if let trailing {
                                trailing
                            }
                        } secondaryContent: {
                            periodNavigationControl(style: .plain)
                                .frame(maxWidth: .infinity)
                        }
                    }
                case .none:
                    RootHeaderGlassPill(
                        showsDivider: trailing != nil,
                        hasTrailing: trailing != nil
                    ) {
                        periodPickerControl
                    } trailing: {
                        if let trailing {
                            trailing
                        }
                    }
                }
            }
            .homeHeaderMatchedControlWidth(
                intrinsicWidth: $headerActionPillIntrinsicWidth,
                matchedWidth: matchedControlWidth
            )

            if showsContextSummary || showsStandalonePeriodNavigation {
                HStack(spacing: DS.Spacing.s) {
                    if showsContextSummary, let summary = headerSummary {
                        HomeHeaderContextSummary(summary: summary)
                        .layoutPriority(0)
                    }

                    Spacer(minLength: 0)

                    if showsStandalonePeriodNavigation {
                        periodNavigationControl(style: .glassIfAvailable)
                            .layoutPriority(1)
                            .homeHeaderMatchedControlWidth(
                                intrinsicWidth: $periodNavigationIntrinsicWidth,
                                matchedWidth: matchedControlWidth
                            )
                    }
                }
            }
        }
        .onPreferenceChange(HomeHeaderControlWidthKey.self) { width in
            let resolvedWidth = width > 0 ? width : nil

            if hasBudget {
                matchedHeaderControlWidth = resolvedWidth
            }

            if let resolvedWidth {
                cachedHeaderControlWidth = resolvedWidth
            }
        }
        .ub_onChange(of: hasBudget) { newValue in
            guard !newValue else { return }
            matchedHeaderControlWidth = nil
            headerActionPillIntrinsicWidth = nil
            periodNavigationIntrinsicWidth = nil
        }
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
                    width: RootHeaderActionMetrics.dimension,
                    height: RootHeaderActionMetrics.dimension,
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
        let dimension = RootHeaderActionMetrics.dimension
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
        let dimension = RootHeaderActionMetrics.dimension
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

    private var emptyStateTrailingControls: some View {
        budgetActionMenu(summary: nil)
    }

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
            minWidth: RootHeaderActionMetrics.dimension,
            maxWidth: .infinity,
            minHeight: RootHeaderActionMetrics.dimension
        )
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
    private var contentContainer: some View {
        ZStack {
            switch vm.state {
            case .initial:
                // Initially nothing is shown to prevent blinking
                Color.clear
                
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .empty:
                // Show empty state only when we've confirmed there are no budgets
                UBEmptyState(
                    iconSystemName: "rectangle.on.rectangle.slash",
                    title: "Budgets",
                    message: emptyStateMessage,
                    primaryButtonTitle: "Create a budget",
                    onPrimaryTap: { isPresentingAddBudget = true }
                )
                .padding(.horizontal, DS.Spacing.l)
                .accessibilityElement(children: .contain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .loaded(let summaries):
                if let first = summaries.first {
#if os(macOS)
                    BudgetDetailsView(
                        budgetObjectID: first.id,
                        displaysBudgetTitle: false,
                        onSegmentChange: { newSegment in
                            self.selectedSegment = newSegment
                        }
                    )
                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                    .id(first.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#else
                    BudgetDetailsView(
                        budgetObjectID: first.id,
                        displaysBudgetTitle: false,
                        headerTopPadding: DS.Spacing.xs,
                        onSegmentChange: { newSegment in
                            self.selectedSegment = newSegment
                        }
                    )
                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                    .id(first.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
                } else {
                    UBEmptyState(
                        iconSystemName: "rectangle.on.rectangle.slash",
                        title: "Budgets",
                        message: emptyStateMessage,
                        primaryButtonTitle: "Create a budget",
                        onPrimaryTap: { isPresentingAddBudget = true }
                    )
                    .padding(.horizontal, DS.Spacing.l)
                    .accessibilityElement(children: .contain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        // Fill remaining viewport under header so centering is exact.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerSectionSpacing: CGFloat {
        let hasPrimarySummary = primarySummary != nil
#if os(macOS)
        return hasPrimarySummary ? 0 : DS.Spacing.xs
#else
        return hasPrimarySummary ? DS.Spacing.xs / 2 : DS.Spacing.s
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
        return horizontalSizeClass == .regular
#else
        return false
#endif
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        budgetPeriod.title(for: date)
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    let summary: BudgetSummary

    var body: some View {
        Group {
            if sizeClass == .compact {
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    budgetTitleView
                    incomeSummaryView
                }
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.l) {
                    budgetTitleView
                    incomeSummaryView
                }
            }
        }
    }

    private var budgetTitleView: some View {
        VStack(alignment: .leading, spacing: HomeHeaderPrimarySummaryStyle.verticalSpacing) {
            Text(summary.budgetName)
                .font(HomeHeaderPrimarySummaryStyle.titleFont)
                .lineLimit(HomeHeaderPrimarySummaryStyle.titleLineLimit)
                .minimumScaleFactor(HomeHeaderPrimarySummaryStyle.titleMinimumScaleFactor)

            Text(summary.periodString)
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

    func body(content: Content) -> some View {
        content
            .background(
                HomeHeaderControlWidthReporter(intrinsicWidth: intrinsicWidth)
            )
            .frame(width: resolvedWidth)
    }

    private var resolvedWidth: CGFloat? {
        let minimum = Self.minimumWidth

        if let matchedWidth, matchedWidth > 0 {
            return max(matchedWidth, minimum)
        }

        if let intrinsic = intrinsicWidth.wrappedValue, intrinsic > 0 {
            return max(intrinsic, minimum)
        }

        return nil
    }

    private static var minimumWidth: CGFloat {
        RootHeaderActionMetrics.dimension + (RootHeaderGlassMetrics.horizontalPadding * 2)
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
            if binding.wrappedValue != width {
                binding.wrappedValue = width
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
