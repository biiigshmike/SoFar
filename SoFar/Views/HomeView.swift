//
//  HomeView.swift
//  SoFar
//
//  Displays month header + adaptive grid of budget cards.
//  Tap a card to open Budget Details. Long-press/right-click a card to Edit Budget.
//
//  Empty-state centering:
//  - We place a ZStack as the content container *below the header*.
//  - When there are no budgets, we show UBEmptyState inside that ZStack.
//  - UBEmptyState uses maxWidth/maxHeight = .infinity, so it centers itself
//    within the ZStack's available area (i.e., the viewport minus the header).
//  - When budgets exist, we show the ScrollView grid in the same ZStack,
//    so there’s no layout jump switching between states.
//

import SwiftUI
import CoreData
import Foundation

// MARK: - HomeView
struct HomeView: View {

    // MARK: State & ViewModel
    @StateObject private var vm = HomeViewModel()

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false

    // MARK: Edit Budget Sheet (Identity-driven)
    // Use an Identifiable wrapper so .sheet(item:) keys by budget identity.
    private struct BudgetToEdit: Identifiable, Equatable {
        let id: NSManagedObjectID
    }
    @State private var budgetToEdit: BudgetToEdit? = nil

    // MARK: Delete Budget Alert (Identity-driven)
    private struct BudgetToDelete: Identifiable, Equatable {
        let id: NSManagedObjectID
    }
    @State private var budgetToDelete: BudgetToDelete? = nil

    // MARK: Layout Constants
    private let cardMinWidth: CGFloat = 340
    private let cardMaxWidth: CGFloat = 520
    private let gridSpacing: CGFloat = DS.Spacing.l

    // MARK: Body
    var body: some View {
        // MARK: Root layout: Header + Content Container
        VStack(alignment: .leading, spacing: DS.Spacing.l) {

            // MARK: Header (Month chevrons + DatePicker)
            header

            // MARK: Content Container
            // ZStack gives us a stable area below the header.
            // - When empty: we show UBEmptyState centered here.
            // - When non-empty: we show the scrollable grid here.
            contentContainer
        }
        // Make the whole screen participate so the ZStack gets the full height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .navigationTitle("Home")
        .appToolbar(
            titleDisplayMode: .large,
            trailingItems: [
                .add { isPresentingAddBudget = true }
            ]
        )
        .searchable(text: $vm.searchQuery, placement: .automatic, prompt: Text("Search budgets"))
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

        // MARK: EDIT SHEET — identity driven
        .sheet(item: $budgetToEdit) { token in
            let (start, end) = Month.range(for: vm.selectedMonth)
            AddBudgetView(
                editingBudgetObjectID: token.id,
                fallbackStartDate: start,
                fallbackEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
            .id(token.id) // double insurance: unique identity per budget
        }

        // MARK: DELETE CONFIRMATION ALERT — identity driven
        .alert(item: $budgetToDelete) { token in
            Alert(
                title: Text("Delete “\(budgetName(for: token.id))”?"),
                message: Text("This will remove the budget. This action cannot be undone."),
                primaryButton: .destructive(Text("Delete"), action: {
                    Task { await vm.deleteBudget(objectID: token.id) }
                }),
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
                // Show loading state with placeholders
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: cardMinWidth, maximum: cardMaxWidth),
                                     spacing: gridSpacing,
                                     alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: gridSpacing
                    ) {
                        // Show 2 placeholder cards while loading
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 200) // Approximate card height
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.card)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .redacted(reason: .placeholder)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
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
                
            case .loaded(_):
                // Show budgets grid with filtered results
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: cardMinWidth, maximum: cardMaxWidth),
                                     spacing: gridSpacing,
                                     alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: gridSpacing
                    ) {
                        // Use filteredBudgets here to apply search filtering
                        ForEach(vm.filteredBudgets) { summary in
                            // MARK: Navigation to Budget Details
                            NavigationLink {
                                BudgetDetailsView(budgetObjectID: summary.id)
                                    .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                                    .id(summary.id) // fresh details view per budget
                            } label: {
                                BudgetCardView(summary: summary)
                            }
                            .buttonStyle(.plain)

                            // MARK: Context Menu → Edit / Delete
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    budgetToEdit = .init(id: summary.id)
                                }
                                Button(role: .destructive) {
                                    budgetToDelete = .init(id: summary.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            // MARK: iOS Swipe Actions (Delete + Edit)
                            #if os(iOS) || targetEnvironment(macCatalyst)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    budgetToDelete = .init(id: summary.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    budgetToEdit = .init(id: summary.id)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            #endif
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

            DatePicker(
                "",
                selection: Binding(
                    get: { vm.selectedMonth },
                    set: { vm.selectedMonth = Month.start(of: $0) }
                ),
                displayedComponents: [.date]
            )
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

    // Helper: Resolve the current name for a budget id (for alerts UI)
    private func budgetName(for id: NSManagedObjectID) -> String {
        let context = CoreDataService.shared.viewContext
        if let budget = try? context.existingObject(with: id) as? Budget {
            let raw = (budget.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? "Budget" : raw
        }
        return "Budget"
    }
}

// MARK: - Deletion Support
@MainActor
extension HomeViewModel {
    /// Deletes a budget by objectID and refreshes the grid.
    /// - Parameter objectID: The NSManagedObjectID of the Budget to delete.
    func deleteBudget(objectID: NSManagedObjectID) async {
        let context = CoreDataService.shared.viewContext
        do {
            if let obj = try? context.existingObject(with: objectID) {
                context.delete(obj)
                try context.save()
            }
            await refresh()
        } catch {
            // TODO: Surface error to a user-visible alert if you add alert handling to HomeViewModel.
            print("Failed to delete budget: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tiny shimmer for placeholder
private extension View {
    /// Lightweight shimmer to hint loading (iOS/macOS). No external deps.
    func shimmer() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.35), location: 0.45),
                            .init(color: .white.opacity(0.0), location: 1.0),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(12))
                .blendMode(.overlay)
                .opacity(0.35)
                .offset(x: -200)
                .mask(self)
                .animation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false),
                    value: UUID() // restart each appearance
                )
        )
    }
}
