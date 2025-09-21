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

    // MARK: Body
    var body: some View {
        mainLayout
        // Make the whole screen participate so the ZStack gets the full height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ub_tabNavigationTitle("Home")
        .toolbar { toolbarContent() }
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
        .ub_surfaceBackground(
            themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    // MARK: Root Layout
    private var mainLayout: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            RootViewTopPlanes(title: "Home") {
                header
            }

            // MARK: Content Container
            // ZStack gives us a stable area below the header.
            // - When empty: we show UBEmptyState centered here.
            // - When non-empty: we show the budget details here.
            contentContainer
        }
    }

    // MARK: Toolbar
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        periodPickerToolbarItem()
        actionToolbarItem()
    }

    @ToolbarContentBuilder
    private func periodPickerToolbarItem() -> some ToolbarContent {
        // Budget period picker varies by platform because
        // `.navigationBarLeading` is unavailable on macOS.
#if os(macOS)
        ToolbarItem(placement: .navigation) {
            Menu {
                ForEach(BudgetPeriod.selectableCases) { period in
                    Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
                }
            } label: {
                Label(budgetPeriod.displayName, systemImage: "calendar")
            }
        }
#else
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                ForEach(BudgetPeriod.selectableCases) { period in
                    Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
                }
            } label: {
                toolbarIconLabel(title: budgetPeriod.displayName, systemImage: "calendar")
            }
            .frame(width: ToolbarButtonMetrics.dimension, height: ToolbarButtonMetrics.dimension)
            .contentShape(Rectangle())
        }
#endif
    }

    @ToolbarContentBuilder
    private func actionToolbarItem() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            actionToolbarItemContent
        }
    }

    @ViewBuilder
    private var actionToolbarItemContent: some View {
        switch vm.state {
        case .empty:
            Button {
                isPresentingAddBudget = true
            } label: {
                toolbarIconLabel(title: "Add Budget", systemImage: "plus")
            }

        case .loaded(let summaries):
            if let first = summaries.first {
                Menu {
                    Button {
                        editingBudget = first
                    } label: {
                        Label("Edit Budget", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        vm.requestDelete(budgetID: first.id)
                    } label: {
                        Label("Delete Budget", systemImage: "trash")
                    }
                } label: {
                    toolbarIconLabel(title: "Actions", systemImage: "ellipsis.circle")
                }
            } else {
                EmptyView()
            }

        default:
            EmptyView()
        }
    }

    private enum ToolbarButtonMetrics {
        static let dimension: CGFloat = 44
    }

    @ViewBuilder
    private func toolbarIconLabel(title: String, systemImage: String) -> some View {
#if os(macOS)
        Label(title, systemImage: systemImage)
#else
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: ToolbarButtonMetrics.dimension, height: ToolbarButtonMetrics.dimension)
            .contentShape(Rectangle())
#endif
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

            Spacer(minLength: 0)

//            DatePicker(
//                "",
//                selection: Binding(
//                    get: { vm.selectedMonth },
//                    set: { vm.selectedMonth = Month.start(of: $0) }
//                ),
//                displayedComponents: [.date]
//            )
            .labelsHidden()
            .ub_compactDatePickerStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        budgetPeriod.title(for: date)
    }
}

