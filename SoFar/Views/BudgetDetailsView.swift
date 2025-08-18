//
//  BudgetDetailsView.swift
//  SoFar
//
//  Budget details with live Core Data-backed lists.
//  Planned & Variable expenses now use SwiftUI List to enable native swipe gestures.
//  UnifiedSwipeActions gives consistent titles/icons and Mail-style full-swipe on iOS.
//

import SwiftUI
import CoreData

// MARK: - BudgetDetailsView
/// Shows a budget header, filters, and a segmented control to switch between
/// Planned and Variable (Unplanned) expenses. Rows live in real Lists so swipe
/// gestures work on iOS/iPadOS and macOS 13+.
struct BudgetDetailsView: View {

    // MARK: Inputs
    let budgetObjectID: NSManagedObjectID

    // MARK: View Model
    @StateObject private var vm: BudgetDetailsViewModel

    // MARK: Theme
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: UI State
    /// Controls the presentation of the “Add…” menu + sheets.
    @State private var isShowingAddMenu = false
    @State private var isPresentingAddPlannedSheet = false
    @State private var isPresentingAddUnplannedSheet = false

    // MARK: Init
    init(budgetObjectID: NSManagedObjectID) {
        self.budgetObjectID = budgetObjectID
        _vm = StateObject(wrappedValue: BudgetDetailsViewModel(budgetObjectID: budgetObjectID))
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header (name + period) + Segmented + Filters
            VStack(alignment: .leading, spacing: DS.Spacing.l) {

                // MARK: Title + Date Range
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.budget?.name ?? "Budget")
                        .font(.largeTitle.bold())
                    if let s = vm.budget?.startDate, let e = vm.budget?.endDate {
                        Text("\(Self.mediumDate(s)) through \(Self.mediumDate(e))")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Segment Picker
                Picker("", selection: $vm.selectedSegment) {
                    Text("Planned Expenses").tag(BudgetDetailsViewModel.Segment.planned)
                    Text("Variable Expenses").tag(BudgetDetailsViewModel.Segment.variable)
                }
                .pickerStyle(.segmented)

                // MARK: Filters
                FilterBar(
                    startDate: $vm.startDate,
                    endDate: $vm.endDate,
                    sort: $vm.sort,
                    onChanged: { /* @FetchRequest-driven children auto-refresh */ },
                    onResetDate: { vm.resetDateWindowToBudget() }
                )
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.m)

            // MARK: Lists
            Group {
                if vm.selectedSegment == .planned {
                    if let budget = vm.budget {
                        PlannedListFR(
                            budget: budget,
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            sort: vm.sort
                        )
                    } else {
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.l)
                    }
                } else {
                    if let cards = (vm.budget?.cards as? Set<Card>) {
                        VariableListFR(
                            attachedCards: Array(cards),
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            sort: vm.sort
                        )
                    } else {
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.Spacing.l)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // let the List take over scrolling
        }
        .navigationTitle("Budget Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingAddMenu = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
        .confirmationDialog("Add",
                            isPresented: $isShowingAddMenu,
                            titleVisibility: .visible) {
            Button("Add Planned Expense") { isPresentingAddPlannedSheet = true }
            Button("Add Variable Expense") { isPresentingAddUnplannedSheet = true }
        }
        .onAppear {
            CoreDataService.shared.ensureLoaded()
            Task { await vm.load() }
        }
        // Pull to refresh to reload expenses with current filters
        .refreshable { await vm.refreshRows() }
        .searchable(text: $vm.searchQuery, placement: .automatic, prompt: Text("Search"))
        // MARK: Add Sheets
        .sheet(isPresented: $isPresentingAddPlannedSheet) {
            AddPlannedExpenseView(
                preselectedBudgetID: vm.budget?.objectID,
                onSaved: { /* lists auto-update via @FetchRequest */ }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
        .sheet(isPresented: $isPresentingAddUnplannedSheet) {
            AddUnplannedExpenseView(
                allowedCardIDs: Set(((vm.budget?.cards as? Set<Card>) ?? []).map { $0.objectID }),
                initialDate: vm.startDate,
                onSaved: { /* lists auto-update via @FetchRequest */ }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    // MARK: Helpers
    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}

// MARK: - FilterBar (unchanged API)
private struct FilterBar: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var sort: BudgetDetailsViewModel.SortOption

    let onChanged: () -> Void
    let onResetDate: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .labelsHidden().ub_compactDatePickerStyle()
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                        .labelsHidden().ub_compactDatePickerStyle()
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(maxWidth: .infinity)

                Button("Reset") { onResetDate() }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Picker("Sort", selection: $sort) {
                Text("A–Z").tag(BudgetDetailsViewModel.SortOption.titleAZ)
                Text("$↓").tag(BudgetDetailsViewModel.SortOption.amountLowHigh)
                Text("$↑").tag(BudgetDetailsViewModel.SortOption.amountHighLow)
                Text("Date ↑").tag(BudgetDetailsViewModel.SortOption.dateOldNew)
                Text("Date ↓").tag(BudgetDetailsViewModel.SortOption.dateNewOld)
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: startDate) { onChanged() }
        .onChange(of: endDate)   { onChanged() }
        .onChange(of: sort)      { onChanged() }
    }
}

// MARK: - PlannedListFR (List-backed; swipe enabled)
private struct PlannedListFR: View {
    @FetchRequest private var rows: FetchedResults<PlannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    @State private var editingItem: PlannedExpense?

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    init(budget: Budget, startDate: Date, endDate: Date, sort: BudgetDetailsViewModel.SortOption) {
        self.sort = sort

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
        Group {
            if rows.isEmpty {
                // MARK: Empty state
                List {
                    Text("No planned expenses in this range.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                }
                .styledList()
            } else {
                // MARK: Real List for native swipe
                List {
                    ForEach(sorted(rows), id: \.objectID) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.transactionDate ?? Date(), style: .date)
                                .font(.headline)
                            Text(item.descriptionText ?? "Untitled")
                                .font(.title3.weight(.semibold))
                            HStack {
                                Text("Planned:").foregroundStyle(.secondary)
                                Text(item.plannedAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            }
                            HStack {
                                Text("Actual:").foregroundStyle(.secondary)
                                Text(item.actualAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        // MARK: Unified swipe → Edit & Delete
                        .unifiedSwipeActions(
                            UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent),
                            onEdit: { editingItem = item },
                            onDelete: { deletePlanned(item) }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                    }
                    .onDelete { indexSet in
                        let items = indexSet.compactMap { idx in sorted(rows).indices.contains(idx) ? sorted(rows)[idx] : nil }
                        items.forEach(deletePlanned(_:))
                    }
                }
                .styledList()
            }
        }
        .sheet(item: $editingItem) { expense in
            AddPlannedExpenseView(
                plannedExpenseID: expense.objectID,
                preselectedBudgetID: expense.budget?.objectID,
                onSaved: {}
            )
            .environment(\.managedObjectContext, viewContext)
        }
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

    // MARK: Delete helper
    /// Deletes a planned expense and saves the context.
    private func deletePlanned(_ item: PlannedExpense) {
        withAnimation {
            viewContext.delete(item)
            do { try viewContext.save() }
            catch { print("Failed to delete planned expense: \(error.localizedDescription)") }
        }
    }
}

// MARK: - VariableListFR (List-backed; swipe enabled)
private struct VariableListFR: View {
    @FetchRequest private var rows: FetchedResults<UnplannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    private let attachedCards: [Card]
    @State private var editingItem: UnplannedExpense?

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    init(attachedCards: [Card], startDate: Date, endDate: Date, sort: BudgetDetailsViewModel.SortOption) {
        self.sort = sort
        self.attachedCards = attachedCards

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
        Group {
            if rows.isEmpty {
                // MARK: Empty state
                List {
                    Text("No variable expenses in this range.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                }
                .styledList()
            } else {
                // MARK: Real List for native swipe
                List {
                    ForEach(sorted(rows), id: \.objectID) { item in
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                            Circle()
                                .fill(Color(hex: item.expenseCategory?.color ?? "#999999") ?? .secondary)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading) {
                                Text(item.descriptionText ?? "Untitled")
                                    .font(.title3.weight(.semibold))
                                if let name = item.expenseCategory?.name {
                                    Text(name)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                Text(Self.mediumDate(item.transactionDate ?? .distantPast))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        // MARK: Unified swipe → Edit & Delete
                        .unifiedSwipeActions(
                            UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent),
                            onEdit: { editingItem = item },
                            onDelete: { deleteUnplanned(item) }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)

                        Divider() // keep your visual rhythm if desired
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(themeManager.selectedTheme.secondaryBackground)
                    }
                    .onDelete { indexSet in
                        let items = indexSet.compactMap { idx in sorted(rows).indices.contains(idx) ? sorted(rows)[idx] : nil }
                        items.forEach(deleteUnplanned(_:))
                    }
                }
                .styledList()
            }
        }
        .sheet(item: $editingItem) { expense in
            AddUnplannedExpenseView(
                unplannedExpenseID: expense.objectID,
                allowedCardIDs: Set(attachedCards.map { $0.objectID }),
                initialDate: expense.transactionDate,
                onSaved: {}
            )
            .environment(\.managedObjectContext, viewContext)
        }
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
    /// Deletes a variable (unplanned) expense and saves the context.
    private func deleteUnplanned(_ item: UnplannedExpense) {
        withAnimation {
            viewContext.delete(item)
            do { try viewContext.save() }
            catch { print("Failed to delete unplanned expense: \(error.localizedDescription)") }
        }
    }
}

// MARK: - Shared List Styling Helpers
private extension View {
    /// Applies the plain list style and hides default backgrounds where supported; keeps your custom look.
    @ViewBuilder
    func styledList() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
#if os(iOS)
                .scrollIndicators(.hidden)
#endif
        } else {
            self.listStyle(.plain)
        }
    }
}
