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

// MARK: - HomeView
struct HomeView: View {

    // MARK: State & ViewModel
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false

    // MARK: Body
    var body: some View {
        // MARK: Root layout: Header + Content Container
        VStack(alignment: .leading, spacing: DS.Spacing.l) {

            // MARK: Header (Month chevrons + DatePicker)
            header

            // MARK: Content Container
            // ZStack gives us a stable area below the header.
            // - When empty: we show UBEmptyState centered here.
            // - When non-empty: we show the budget details here.
            contentContainer
        }
        // Make the whole screen participate so the ZStack gets the full height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Home")
        .toolbar {
            if case .empty = vm.state {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddBudget = true
                    } label: {
                        Label("Add Budget", systemImage: "plus")
                    }
                }
            }
        }
        .refreshable { await vm.refresh() }
        .task {
            CoreDataService.shared.ensureLoaded()
            vm.startIfNeeded()
        }

        // MARK: ADD SHEET — present new budget UI for the selected month
        .sheet(isPresented: $isPresentingAddBudget) {
            let (start, end) = Month.range(for: vm.selectedMonth)
            AddBudgetView(
                initialStartDate: start,
                initialEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
        }

        .background(themeManager.selectedTheme.background.ignoresSafeArea())
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
                    message: "No budgets in \(title(for: vm.selectedMonth)). Tap + to create a new budget for this month.",
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
                        message: "No budgets in \(title(for: vm.selectedMonth)). Tap + to create a new budget for this month.",
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
            Button { vm.adjustSelectedMonth(byMonths: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(title(for: vm.selectedMonth))
                .font(.title2).bold()

            Button { vm.adjustSelectedMonth(byMonths: +1) } label: {
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
        .padding(.horizontal, DS.Spacing.s)
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}

