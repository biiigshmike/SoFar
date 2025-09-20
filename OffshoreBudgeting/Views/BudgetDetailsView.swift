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
import Combine
#if os(iOS)
import UIKit
#endif

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

            // MARK: Header (name + summary + controls)
            VStack(alignment: .leading, spacing: DS.Spacing.l) {

                // MARK: Title + Date Range
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.budget?.name ?? "Budget")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let s = vm.budget?.startDate, let e = vm.budget?.endDate {
                        Text("\(Self.mediumDate(s)) through \(Self.mediumDate(e))")
                            .foregroundStyle(.secondary)
                    }
                }

                if let summary = vm.summary {
                    SummarySection(summary: summary, selectedSegment: vm.selectedSegment)
                    if !summary.categoryBreakdown.isEmpty {
                        CategoryTotalsRow(categories: summary.categoryBreakdown)
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
            .padding(.bottom, DS.Spacing.m)

            // MARK: Lists
            Group {
                if vm.selectedSegment == .planned {
                    if let budget = vm.budget {
                        PlannedListFR(
                            budget: budget,
                            startDate: vm.startDate,
                            endDate: vm.endDate,
                            sort: vm.sort,
                            onAddTapped: { isPresentingAddPlannedSheet = true },
                            onTotalsChanged: { Task { await vm.refreshRows() } }
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
                            sort: vm.sort,
                            onAddTapped: { isPresentingAddUnplannedSheet = true },
                            onTotalsChanged: { Task { await vm.refreshRows() } }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
#if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Button {
                        isShowingAddMenu = true
                    } label: {
                        Label("Add Expense", systemImage: "plus")
                    }
                    .popover(isPresented: $isShowingAddMenu,
                             attachmentAnchor: .rect(.bounds),
                             arrowEdge: .top) {
                        addMenuPopover
                    }
                } else {
                    Button {
                        isShowingAddMenu = true
                    } label: {
                        Label("Add Expense", systemImage: "plus")
                    }
                    .confirmationDialog("Add",
                                        isPresented: $isShowingAddMenu,
                                        titleVisibility: .visible) {
                        Button("Add Planned Expense") { isPresentingAddPlannedSheet = true }
                            .buttonStyle(.plain)
                        Button("Add Variable Expense") { isPresentingAddUnplannedSheet = true }
                            .buttonStyle(.plain)
                    }
                }
#else
                Menu {
                    Button("Add Planned Expense") { isPresentingAddPlannedSheet = true }
                    Button("Add Variable Expense") { isPresentingAddUnplannedSheet = true }
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
#endif
            }
        }
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
        .onAppear {
            CoreDataService.shared.ensureLoaded()
            Task { await vm.load() }
        }
        // Pull to refresh to reload expenses with current filters
        .refreshable { await vm.refreshRows() }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .dataStoreDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            Task { await vm.load() }
        }
        //.searchable(text: $vm.searchQuery, placement: .toolbar, prompt: Text("Search"))
        // MARK: Add Sheets
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
    }

    @ViewBuilder
    private var addMenuPopover: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Button("Add Planned Expense") {
                isShowingAddMenu = false
                isPresentingAddPlannedSheet = true
            }
            Button("Add Variable Expense") {
                isShowingAddMenu = false
                isPresentingAddUnplannedSheet = true
            }
        }
        .buttonStyle(.plain)
        .padding(DS.Spacing.m)
        .frame(minWidth: 200, alignment: .leading)
    }

    // MARK: Helpers
    private static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}

// MARK: - SummarySection
private struct SummarySection: View {
    let summary: BudgetSummary
    let selectedSegment: BudgetDetailsViewModel.Segment

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.l) {
            // MARK: Sum of Expenses
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSegment == .planned ? "Planned Expenses" : "Variable Expenses")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(CurrencyFormatterHelper.string(for: selectedSegment == .planned ? summary.plannedExpensesActualTotal : summary.variableExpensesTotal))
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 0)

            // MARK: Income/Savings Grid
            if #available(iOS 16.0, macOS 13.0, *) {
                Grid(horizontalSpacing: DS.Spacing.m, verticalSpacing: 5) {
                    GridRow {
                        Text("POTENTIAL INCOME")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("POTENTIAL SAVINGS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    GridRow {
                        Text(CurrencyFormatterHelper.string(for: summary.potentialIncomeTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.plannedIncome)
                        Text(CurrencyFormatterHelper.string(for: summary.potentialSavingsTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.savingsGood)
                    }
                    GridRow {
                        Text("ACTUAL INCOME")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("ACTUAL SAVINGS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    GridRow {
                        Text(CurrencyFormatterHelper.string(for: summary.actualIncomeTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.actualIncome)
                        Text(CurrencyFormatterHelper.string(for: summary.actualSavingsTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.m) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("POTENTIAL INCOME")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(CurrencyFormatterHelper.string(for: summary.potentialIncomeTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.plannedIncome)
                        Text("ACTUAL INCOME")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(CurrencyFormatterHelper.string(for: summary.actualIncomeTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.actualIncome)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("POTENTIAL SAVINGS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(CurrencyFormatterHelper.string(for: summary.potentialSavingsTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(DS.Colors.savingsGood)
                        Text("ACTUAL SAVINGS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(CurrencyFormatterHelper.string(for: summary.actualSavingsTotal))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(summary.actualSavingsTotal >= 0 ? DS.Colors.savingsGood : DS.Colors.savingsBad)
                    }
                }
            }
        }
    }
}

// MARK: - CategoryTotalsRow
/// Horizontally scrolling pills showing spend per category.
private struct CategoryTotalsRow: View {
    let categories: [BudgetSummary.CategorySpending]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.s) {
                ForEach(categories) { cat in
                    HStack(spacing: DS.Spacing.s) {
                        Circle()
                            .fill(Color(hex: cat.hexColor ?? "#999999") ?? .secondary)
                            .frame(width: 10, height: 10)
                        Text(cat.categoryName)
                            .font(.subheadline.weight(.semibold))
                        Text(CurrencyFormatterHelper.string(for: cat.amount))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(DS.Colors.chipFill)
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.l)
        }
        .ub_hideScrollIndicators()
        .frame(height:22)
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
//            HStack(spacing: DS.Spacing.m) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Start Date").font(.caption).foregroundStyle(.secondary)
//                    DatePicker("", selection: $startDate, displayedComponents: [.date])
//                        .labelsHidden().ub_compactDatePickerStyle()
//                }
//                .frame(maxWidth: .infinity)
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("End Date").font(.caption).foregroundStyle(.secondary)
//                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
//                        .labelsHidden().ub_compactDatePickerStyle()
//                }
//                .frame(maxWidth: .infinity)
//
//                Spacer().frame(maxWidth: .infinity)
//
//                Button("Reset") { onResetDate() }
//                    .frame(maxWidth: .infinity, alignment: .trailing)
//            }

            Picker("Sort", selection: $sort) {
                Text("A–Z").tag(BudgetDetailsViewModel.SortOption.titleAZ)
                Text("$↓").tag(BudgetDetailsViewModel.SortOption.amountLowHigh)
                Text("$↑").tag(BudgetDetailsViewModel.SortOption.amountHighLow)
                Text("Date ↑").tag(BudgetDetailsViewModel.SortOption.dateOldNew)
                Text("Date ↓").tag(BudgetDetailsViewModel.SortOption.dateNewOld)
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: startDate) { _ in onChanged() }
        .onChange(of: endDate)   { _ in onChanged() }
        .onChange(of: sort)      { _ in onChanged() }
    }
}

// MARK: - PlannedListFR (List-backed; swipe enabled)
private struct PlannedListFR: View {
    @FetchRequest private var rows: FetchedResults<PlannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    private let onAddTapped: () -> Void
    private let onTotalsChanged: () -> Void
    @State private var editingItem: PlannedExpense?
    @State private var itemToDelete: PlannedExpense?
    @State private var showDeleteAlert = false

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    init(budget: Budget, startDate: Date, endDate: Date, sort: BudgetDetailsViewModel.SortOption, onAddTapped: @escaping () -> Void, onTotalsChanged: @escaping () -> Void) {
        self.sort = sort
        self.onAddTapped = onAddTapped
        self.onTotalsChanged = onTotalsChanged

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
                // MARK: Empty state
                UBEmptyState(
                    iconSystemName: "list.bullet.rectangle",
                    title: "Planned Expenses",
                    message: "No planned expenses in this range.",
                    primaryButtonTitle: "Add Planned Expense",
                    onPrimaryTap: onAddTapped
                )
                .padding(.horizontal, DS.Spacing.l)
            } else {
                // MARK: Real List for native swipe
                List {
                    ForEach(items, id: \.objectID) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.transactionDate ?? Date(), style: .date)
                                .font(.headline)
                            Text(item.descriptionText ?? "Untitled")
                                .font(.title3.weight(.semibold))
                            HStack {
                                Text("Planned:").foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: item.plannedAmount))
                            }
                            HStack {
                                Text("Actual:").foregroundStyle(.secondary)
                                Text(CurrencyFormatterHelper.string(for: item.actualAmount))
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        // MARK: Unified swipe → Edit & Delete
                        .unifiedSwipeActions(
                            // Disable full swipe-to-delete to prevent unintended automatic deletes. Only
                            // tapping the Delete button will confirm removal.
                            UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent,
                                               allowsFullSwipeToDelete: false),
                            onEdit: { editingItem = item },
                            onDelete: {
                                if confirmBeforeDelete {
                                    itemToDelete = item
                                    showDeleteAlert = true
                                } else {
                                    deletePlanned(item)
                                }
                            }
                        )
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
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
                .styledList()
                .padding(.horizontal, DS.Spacing.l)
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
    /// Deletes a planned expense using the `PlannedExpenseService`. This ensures any
    /// additional business logic (such as cascading template children) runs
    /// consistently. The deletion is wrapped in an animation and followed by
    /// refreshing totals. Errors are logged and rolled back on failure.
    private func deletePlanned(_ item: PlannedExpense) {
        withAnimation {
            // Step 1: Log that deletion was triggered. This helps verify that the
            // swipe or context‑menu action is correctly invoking this helper.
            print("deletePlanned called for: \(item.descriptionText ?? "<no description>")")
            do {
                try PlannedExpenseService.shared.delete(item)
                // Defer the totals refresh to the next run loop. Updating the view model
                // immediately inside the delete animation can cause extra refreshes. This
                // async dispatch schedules the update after the current cycle completes.
                DispatchQueue.main.async {
                    onTotalsChanged()
                }
            } catch {
                print("Failed to delete planned expense: \(error.localizedDescription)")
                viewContext.rollback()
            }
        }
    }
}

// MARK: - VariableListFR (List-backed; swipe enabled)
private struct VariableListFR: View {
    @FetchRequest private var rows: FetchedResults<UnplannedExpense>
    private let sort: BudgetDetailsViewModel.SortOption
    private let attachedCards: [Card]
    private let onAddTapped: () -> Void
    private let onTotalsChanged: () -> Void
    @State private var editingItem: UnplannedExpense?
    @State private var itemToDelete: UnplannedExpense?
    @State private var showDeleteAlert = false

    // MARK: Environment for deletes
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue) private var confirmBeforeDelete: Bool = true

    init(attachedCards: [Card], startDate: Date, endDate: Date, sort: BudgetDetailsViewModel.SortOption, onAddTapped: @escaping () -> Void, onTotalsChanged: @escaping () -> Void) {
        self.sort = sort
        self.attachedCards = attachedCards
        self.onAddTapped = onAddTapped
        self.onTotalsChanged = onTotalsChanged

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
                // MARK: Empty state
                UBEmptyState(
                    iconSystemName: "creditcard",
                    title: "Variable Expenses",
                    message: "No variable expenses in this range.",
                    primaryButtonTitle: "Add Variable Expense",
                    onPrimaryTap: onAddTapped
                )
                .padding(.horizontal, DS.Spacing.l)
            } else {
                // MARK: Real List for native swipe
                List {
                    ForEach(items, id: \.objectID) { item in
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
                                Text(CurrencyFormatterHelper.string(for: item.amount))
                                Text(Self.mediumDate(item.transactionDate ?? .distantPast))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        // MARK: Unified swipe → Edit & Delete
                        .unifiedSwipeActions(
                            UnifiedSwipeConfig(editTint: themeManager.selectedTheme.secondaryAccent,
                                               allowsFullSwipeToDelete: false),
                            onEdit: { editingItem = item },
                            onDelete: {
                                if confirmBeforeDelete {
                                    itemToDelete = item
                                    showDeleteAlert = true
                                } else {
                                    deleteUnplanned(item)
                                }
                            }
                        )
                        .listRowBackground(themeManager.selectedTheme.secondaryBackground)
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
                .styledList()
                .padding(.horizontal, DS.Spacing.l)
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
                print("deleteUnplanned called for: \(item.descriptionText ?? "<no description>")")
                try service.delete(item, cascadeChildren: true)
                // Defer totals refresh to the next run loop to avoid view update loops.
                DispatchQueue.main.async {
                    onTotalsChanged()
                }
            } catch {
                print("Failed to delete unplanned expense: \(error.localizedDescription)")
                viewContext.rollback()
            }
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

// MARK: - Currency Formatting Helper
private enum CurrencyFormatterHelper {
    private static let fallbackCurrencyCode = "USD"

    static func string(for amount: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return amount.formatted(.currency(code: currencyCode))
        } else {
            return legacyString(for: amount)
        }
    }

    private static var currencyCode: String {
        if #available(iOS 16.0, macOS 13.0, *) {
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
