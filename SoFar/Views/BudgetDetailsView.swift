//
//  BudgetDetailsView.swift
//  SoFar
//
//  Budget details with live Core Data-backed lists.
//  Planned & Variable expenses use @FetchRequest so they always reflect
//  the current budget + date window without manual refresh timing.
//

import SwiftUI
import CoreData

// MARK: - BudgetDetailsView
struct BudgetDetailsView: View {

    // MARK: Inputs
    let budgetObjectID: NSManagedObjectID

    // MARK: View Model
    @StateObject private var vm: BudgetDetailsViewModel

    // MARK: UI State
    /// Controls the presentation of the “Add…” action sheet.
    @State private var isShowingAddMenu = false
    /// Flags controlling the modal presentation of the add‑planned and add‑unplanned sheets.
    /// Using separate booleans allows independent control for each sheet without
    /// resorting to push‑style navigation.  When true, the corresponding sheet
    /// is presented via a `.sheet` modifier at the bottom of this view.
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
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {

                    // MARK: Header (Name + Period)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.budget?.name ?? "Budget")
                            .font(.largeTitle.bold())
                        if let s = vm.budget?.startDate, let e = vm.budget?.endDate {
                            Text("\(Self.mediumDate(s)) through \(Self.mediumDate(e))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.top, DS.Spacing.m)

                    // MARK: Segmented
                    Picker("", selection: $vm.selectedSegment) {
                        Text("Planned Expenses").tag(BudgetDetailsViewModel.Segment.planned)
                        Text("Variable Expenses").tag(BudgetDetailsViewModel.Segment.variable)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.l)

                    // MARK: Filters
                    FilterBar(
                        startDate: $vm.startDate,
                        endDate: $vm.endDate,
                        sort: $vm.sort,
                        onChanged: { /* lists refetch automatically because init params change */ },
                        onResetDate: {
                            vm.resetDateWindowToBudget()
                        }
                    )
                    .padding(.horizontal, DS.Spacing.l)

                    // MARK: Lists (live)
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
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.bottom, DS.Spacing.l)
                }
            }
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
        .searchable(text: $vm.searchQuery, placement: .automatic, prompt: Text("Search"))
        // Modal sheets for adding planned or unplanned expenses.  Sheets are
        // preferred over navigation destinations so that the edit forms
        // present in a pop‑up window on macOS and slide‑up sheet on iOS/iPadOS.
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

// MARK: - PlannedListFR (live fetch)
private struct PlannedListFR: View {
    @FetchRequest private var rows: FetchedResults<PlannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption

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
        if rows.isEmpty {
            Text("No planned expenses in this range.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.m) {
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
                        Divider()
                    }
                }
            }
        }
    }

    // Sorting applied after fetch to honor user choice
    private func sorted(_ arr: FetchedResults<PlannedExpense>) -> [PlannedExpense] {
        var rows = Array(arr)
        switch sort {
        case .titleAZ:
            rows.sort { ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending }
        case .amountLowHigh:
            rows.sort { $0.plannedAmount < $1.plannedAmount }
        case .amountHighLow:
            rows.sort { $0.plannedAmount > $1.plannedAmount }
        case .dateOldNew:
            rows.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            rows.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return rows
    }

    // Inclusive day bounds
    private static func clamp(_ range: ClosedRange<Date>) -> (Date, Date) {
        let cal = Calendar.current
        let s = cal.startOfDay(for: range.lowerBound)
        let e = cal.date(byAdding: DateComponents(day: 1, second: -1),
                         to: cal.startOfDay(for: range.upperBound)) ?? range.upperBound
        return (s, e)
    }
}

// MARK: - VariableListFR (live fetch)
private struct VariableListFR: View {
    @FetchRequest private var rows: FetchedResults<UnplannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption

    init(attachedCards: [Card], startDate: Date, endDate: Date, sort: BudgetDetailsViewModel.SortOption) {
        self.sort = sort

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
        if rows.isEmpty {
            Text("No variable expenses in this range.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.m) {
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
                    Divider()
                }
            }
        }
    }

    private func sorted(_ arr: FetchedResults<UnplannedExpense>) -> [UnplannedExpense] {
        var rows = Array(arr)
        switch sort {
        case .titleAZ:
            rows.sort { ($0.descriptionText ?? "").localizedCaseInsensitiveCompare($1.descriptionText ?? "") == .orderedAscending }
        case .amountLowHigh:
            rows.sort { $0.amount < $1.amount }
        case .amountHighLow:
            rows.sort { $0.amount > $1.amount }
        case .dateOldNew:
            rows.sort { ($0.transactionDate ?? .distantPast) < ($1.transactionDate ?? .distantPast) }
        case .dateNewOld:
            rows.sort { ($0.transactionDate ?? .distantPast) > ($1.transactionDate ?? .distantPast) }
        }
        return rows
    }

    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    private static func clamp(_ range: ClosedRange<Date>) -> (Date, Date) {
        let cal = Calendar.current
        let s = cal.startOfDay(for: range.lowerBound)
        let e = cal.date(byAdding: DateComponents(day: 1, second: -1),
                         to: cal.startOfDay(for: range.upperBound)) ?? range.upperBound
        return (s, e)
    }
}
