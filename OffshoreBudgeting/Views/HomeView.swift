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
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue) private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue
    private var budgetPeriod: BudgetPeriod { BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly }

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false
    @State private var editingBudget: BudgetSummary?

    // MARK: Environment
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Body
    var body: some View {
        mainLayout
        // Make the whole screen participate so the ZStack gets the full height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ub_tabNavigationTitle("Home")
        .refreshable { await vm.refresh() }
        .task {
            CoreDataService.shared.ensureLoaded()
            vm.startIfNeeded()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .dataStoreDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            Task { await vm.refresh() }
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
                triggerAddExpense(.budgetDetailsRequestAddPlannedExpense)
            }
            Button("Add Variable Expense") {
                triggerAddExpense(.budgetDetailsRequestAddVariableExpense)
            }
        }
        .onChange(of: isShowingAddExpenseMenu) { _, newValue in
            if !newValue {
                addMenuTargetBudgetID = nil
            }
        }
        .ub_surfaceBackground(
            themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    // MARK: Root Layout
    private var mainLayout: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            headerSection

            // MARK: Content Container
            // ZStack gives us a stable area below the header.
            // - When empty: we show UBEmptyState centered here.
            // - When non-empty: we show the budget details here.
            contentContainer
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            RootViewTopPlanes(
                title: "Home",
                topPaddingStyle: .navigationBarAligned
            ) {
                headerActions
            }

            header
                .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        let trailing = trailingActionControl
#if os(macOS)
        HStack(spacing: DS.Spacing.s) {
            periodPickerControl
            if let trailing {
                trailing
            }
        }
#else
        RootHeaderGlassPill(showsDivider: trailing != nil) {
            periodPickerControl
        } trailing: {
            if let trailing {
                trailing
            } else {
                trailingPlaceholder
            }
        }
#endif
    }

    @ViewBuilder
    private var periodPickerControl: some View {
        Menu {
            ForEach(BudgetPeriod.selectableCases) { period in
                Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
            }
        } label: {
#if os(macOS)
            Label(budgetPeriod.displayName, systemImage: "calendar")
#else
            RootHeaderControlIcon(systemImage: "calendar")
                .accessibilityLabel(budgetPeriod.displayName)
#endif
        }
#if os(iOS)
        .modifier(HideMenuIndicatorIfPossible())
#endif
    }

    private var trailingActionControl: AnyView? {
        switch vm.state {
        case .empty:
            return AnyView(addBudgetButton)
        case .loaded(let summaries):
            if let first = summaries.first {
                return AnyView(trailingControls(for: first))
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    private var trailingPlaceholder: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func trailingControls(for summary: BudgetSummary) -> some View {
        let dimension = RootHeaderActionMetrics.dimension
        return HStack(spacing: 0) {
            addExpenseButton(for: summary.id)
            Rectangle()
                .fill(glassDividerColor)
                .frame(width: 1, height: dimension)
                .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
                .allowsHitTesting(false)
            budgetActionMenu(for: summary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func addExpenseButton(for budgetID: NSManagedObjectID) -> some View {
        let dimension = RootHeaderActionMetrics.dimension
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
#if os(iOS)
        .modifier(HideMenuIndicatorIfPossible())
#else
        .menuStyle(.borderlessButton)
#endif
        .frame(width: dimension, height: dimension)
        .contentShape(Rectangle())
        .accessibilityLabel("Add Expense")
    }

    private var addBudgetButton: some View {
        Button {
            isPresentingAddBudget = true
        } label: {
            RootHeaderControlIcon(systemImage: "plus")
        }
#if os(iOS)
        .buttonStyle(RootHeaderActionButtonStyle())
#else
        .buttonStyle(.plain)
#endif
        .accessibilityLabel("Add Budget")
    }

    private func budgetActionMenu(for summary: BudgetSummary) -> some View {
        Menu {
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
            RootHeaderControlIcon(systemImage: "ellipsis")
                .accessibilityLabel("Budget Actions")
        }
#if os(iOS)
        .modifier(HideMenuIndicatorIfPossible())
#endif
        .frame(width: RootHeaderActionMetrics.dimension, height: RootHeaderActionMetrics.dimension)
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
                    message: "No budget found for \(title(for: vm.selectedDate)). Tap + to create a new budget for this period.",
                    primaryButtonTitle: "Create a budget",
                    onPrimaryTap: { isPresentingAddBudget = true }
                )
                .padding(.horizontal, DS.Spacing.l)
                .accessibilityElement(children: .contain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .loaded(let summaries):
                if let first = summaries.first {
                    BudgetDetailsView(budgetObjectID: first.id)
                        .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                        .id(first.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    UBEmptyState(
                        iconSystemName: "rectangle.on.rectangle.slash",
                        title: "Budgets",
                        message: "No budget found for \(title(for: vm.selectedDate)). Tap + to create a new budget for this period.",
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

    // MARK: Header
    private var header: some View {
        HStack(spacing: DS.Spacing.s) {
            Button { vm.adjustSelectedPeriod(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(title(for: vm.selectedDate))
                .font(.title2).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Button { vm.adjustSelectedPeriod(by: +1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        budgetPeriod.title(for: date)
    }

    private var glassDividerColor: Color {
        let theme = themeManager.selectedTheme
        if theme == .system {
            return colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.18)
        } else {
            let darkOpacity: Double = 0.55
            let lightOpacity: Double = 0.35
            return theme.resolvedTint.opacity(colorScheme == .dark ? darkOpacity : lightOpacity)
        }
    }

    private func triggerAddExpense(_ notificationName: Notification.Name, budgetID: NSManagedObjectID) {
        NotificationCenter.default.post(name: notificationName, object: budgetID)
    }
}

// MARK: - Header Action Helpers
#if os(iOS)
private struct HideMenuIndicatorIfPossible: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.menuIndicator(.hidden)
        } else {
            content
        }
    }
}
#endif

