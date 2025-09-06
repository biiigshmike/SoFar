//
//  AddPlannedExpenseView.swift
//  SoFar
//
//  Simple, polished form for adding a planned expense to a budget.
//

import SwiftUI
import CoreData

// MARK: - AddPlannedExpenseView
struct AddPlannedExpenseView: View {

    // MARK: Inputs
    /// Existing PlannedExpense to edit; nil when adding.
    let plannedExpenseID: NSManagedObjectID?
    /// Budget to preselect when adding; ignored if `plannedExpenseID` is provided.
    let preselectedBudgetID: NSManagedObjectID?
    /// If true, the "Use in future budgets?" toggle will start ON when the view first appears.
    let defaultSaveAsGlobalPreset: Bool
    /// When true, shows a toggle allowing the user to optionally assign a budget.
    let showAssignBudgetToggle: Bool
    /// Called after a successful save.
    let onSaved: () -> Void

    // MARK: State
    /// We don't call `dismiss()` directly anymore (the scaffold handles it),
    /// but we keep this in case future platform-specific work needs it.
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AddPlannedExpenseViewModel
    @State private var isAssigningToBudget: Bool

    /// Guard to apply `defaultSaveAsGlobalPreset` only once on first load.
    @State private var didApplyDefaultGlobal = false

    @State private var budgetSearchText = ""

    private var filteredBudgets: [Budget] {
        vm.allBudgets.filter { budgetSearchText.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(budgetSearchText) }
    }

    // MARK: Layout
    #if os(macOS)
    private let cardRowHeight: CGFloat = 150
    #else
    private let cardRowHeight: CGFloat = 160
    #endif

    // MARK: Init
    /// Designated initializer.
    /// - Parameters:
    ///   - plannedExpenseID: ID of expense.
    ///  - preselectedBudgetID: Optional budget objectID to preselect.
    ///   - defaultSaveAsGlobalPreset: When true, defaults the "Use in future budgets?" toggle to ON on first load.
    ///   - showAssignBudgetToggle: Toggle whether or not adding to budget now or later.
    ///  - onSaved: Closure invoked after `vm.save()` succeeds.
    init(
        plannedExpenseID: NSManagedObjectID? = nil,
        preselectedBudgetID: NSManagedObjectID? = nil,
        defaultSaveAsGlobalPreset: Bool = false,
        showAssignBudgetToggle: Bool = false,
        onSaved: @escaping () -> Void
    ) {
        self.plannedExpenseID = plannedExpenseID
        self.preselectedBudgetID = preselectedBudgetID
        self.defaultSaveAsGlobalPreset = defaultSaveAsGlobalPreset
        self.showAssignBudgetToggle = showAssignBudgetToggle
        self.onSaved = onSaved
        _isAssigningToBudget = State(initialValue: !showAssignBudgetToggle)
        _vm = StateObject(
            wrappedValue: AddPlannedExpenseViewModel(
                plannedExpenseID: plannedExpenseID,
                preselectedBudgetID: preselectedBudgetID,
                requiresBudgetSelection: !showAssignBudgetToggle
            )
        )
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: vm.isEditing ? "Edit Planned Expense" : "Add Planned Expense",
            saveButtonTitle: vm.isEditing ? "Save Changes" : "Save",
            isSaveEnabled: vm.canSave,
            onSave: { trySave() }
        ) {
            // MARK: Card Selection
            UBFormSection("Card", isUppercased: true) {
                CardPickerRow(
                    allCards: vm.allCards,
                    selectedCardID: $vm.selectedCardID,
                    includeNoneTile: true
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: cardRowHeight)
                .ub_hideScrollIndicators()
            }

            // MARK: Budget Assignment
            if showAssignBudgetToggle {
                UBFormSection("Add to a budget now?", isUppercased: true) {
                    Toggle("Select a Budget", isOn: $isAssigningToBudget)
                }
                if isAssigningToBudget {
                    budgetPickerSection
                }
            } else {
                budgetPickerSection
            }

            // MARK: Category Selection
            UBFormSection("Category", isUppercased: true) {
                CategoryChipsRow(selectedCategoryID: $vm.selectedCategoryID)
            }
            .accessibilityElement(children: .contain)

            // MARK: Individual Fields
            // Instead of grouping all fields into a single section, mirror the
            // Add Card form by giving each input its own section with a
            // descriptive header.  This pushes the label outside of the cell
            // (e.g. “Name” in Add Card) and allows the actual `TextField`
            // to be empty, so the placeholder remains visible and left‑aligned.

            // Expense Description
            UBFormSection("Expense Description", isUppercased: true) {
                // Use an empty label and a prompt for true placeholder styling on modern OSes.
                UBFormRow {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        TextField("", text: $vm.descriptionText, prompt: Text("Electric"))
                            .ub_noAutoCapsAndCorrection()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    } else {
                        TextField("Rent", text: $vm.descriptionText)
                            .ub_noAutoCapsAndCorrection()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Expense Description")
                    }
                }
            }

            // Planned Amount
            UBFormSection("Planned Amount", isUppercased: true) {
                UBFormRow {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        TextField("", text: $vm.plannedAmountString, prompt: Text("100"))
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Planned Amount")
                    } else {
                        TextField("2000", text: $vm.plannedAmountString)
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Planned Amount")
                    }
                }
            }

            // Actual Amount
            UBFormSection("Actual Amount", isUppercased: true) {
                UBFormRow {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        TextField("", text: $vm.actualAmountString, prompt: Text("102.50"))
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Actual Amount")
                    } else {
                        TextField("102.50", text: $vm.actualAmountString)
                            .ub_decimalKeyboard()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Actual Amount")
                    }
                }
            }

            // Transaction Date
            UBFormSection("Transaction Date", isUppercased: true) {
                // Hide the label of the DatePicker itself; the section header supplies the label.
                DatePicker("", selection: $vm.transactionDate, displayedComponents: [.date])
                    .labelsHidden()
                    .ub_compactDatePickerStyle()
                    .accessibilityLabel("Transaction Date")
            }

            // MARK: Use in future budgets?
            UBFormSection("Use in future budgets?", isUppercased: true) {
                Toggle("Use in future budgets?", isOn: $vm.saveAsGlobalPreset)
            }
        }
        .task {
            // MARK: Lifecycle
            await vm.load()

            // Apply the default only when adding and only once.
            if !vm.isEditing && !didApplyDefaultGlobal {
                vm.saveAsGlobalPreset = defaultSaveAsGlobalPreset
                didApplyDefaultGlobal = true
            }
        }
        .onChange(of: isAssigningToBudget) { _, newValue in
            guard showAssignBudgetToggle else { return }
            if newValue {
                vm.selectedBudgetID = vm.allBudgets.first?.objectID
            } else {
                vm.selectedBudgetID = nil
            }
        }
        .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
    }

    // MARK: Actions
    /// Attempts to save; on success calls `onSaved`.
    /// - Returns: `true` if the sheet should dismiss, `false` to stay open.
    private func trySave() -> Bool {
        guard vm.canSave else { return false }
        do {
            try vm.save()
            onSaved()
            // Resign keyboard on iOS for a neat dismissal.
            ub_dismissKeyboard()
            return true
        } catch {
            // Present error via UIKit alert on iOS; macOS simply returns false.
            #if canImport(UIKit)
            let alert = UIAlertController(
                title: "Couldn’t Save",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?
                .rootViewController?
                .present(alert, animated: true)
            #endif
            return false
        }
    }

    @ViewBuilder
    private var budgetPickerSection: some View {
        UBFormSection("Choose Budget", isUppercased: true) {
            UBFormRow {
                // Use a custom binding so the selection is cleared immediately
                // when the search text changes to a string that doesn't include
                // the currently selected budget.  This avoids transient invalid
                // picker selections that trigger console warnings.
                TextField(
                    "Search Budgets",
                    text: Binding(
                        get: { budgetSearchText },
                        set: { newValue in
                            budgetSearchText = newValue
                            let matching = vm.allBudgets.filter { budget in
                                newValue.isEmpty || (budget.name ?? "").localizedCaseInsensitiveContains(newValue)
                            }
                            if newValue.isEmpty ||
                                !matching.contains(where: { $0.objectID == vm.selectedBudgetID }) {
                                vm.selectedBudgetID = nil
                            }
                        }
                    )
                )
                .ub_noAutoCapsAndCorrection()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            UBFormRow {
                // Use a Menu instead of a Picker to prevent warnings about
                // invalid selections when the available budgets change.
                Menu {
                    ForEach(filteredBudgets, id: \.objectID) { budget in
                        Button(budget.name ?? "Untitled") {
                            vm.selectedBudgetID = budget.objectID
                        }
                    }
                } label: {
                    Text(
                        vm.allBudgets.first(where: { $0.objectID == vm.selectedBudgetID })?.name ?? "Select Budget"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(budgetSearchText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - CategoryChipsRow
/// Reusable horizontally scrolling row of category chips with an Add button.
private struct CategoryChipsRow: View {

    @Binding var selectedCategoryID: NSManagedObjectID?
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true,
                                           selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
    )
    private var categories: FetchedResults<ExpenseCategory>

    @State private var isPresentingNewCategory = false

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            AddCategoryPill { isPresentingNewCategory = true }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.s) {
                    if categories.isEmpty {
                        Text("No categories yet")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(categories, id: \.objectID) { cat in
                            CategoryChip(
                                name: cat.name ?? "Untitled",
                                colorHex: cat.color ?? "#999999",
                                isSelected: selectedCategoryID == cat.objectID
                            )
                            .onTapGesture { selectedCategoryID = cat.objectID }
                        }
                    }
                }
                .padding(.trailing, DS.Spacing.s)
            }
            .ub_hideScrollIndicators()
        }
        .sheet(isPresented: $isPresentingNewCategory) {
            ExpenseCategoryEditorSheet(
                initialName: "",
                initialHex: "#4E9CFF"
            ) { name, hex in
                let category = ExpenseCategory(context: viewContext)
                category.id = UUID()
                category.name = name
                category.color = hex
                do {
                    try viewContext.obtainPermanentIDs(for: [category])
                    try viewContext.save()
                    selectedCategoryID = category.objectID
                } catch {
                    #if DEBUG
                    print("Failed to create category:", error.localizedDescription)
                    #endif
                }
            }
            .presentationDetents([.medium])
            .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: categories.count) { _, _ in
            if selectedCategoryID == nil, let first = categories.first {
                selectedCategoryID = first.objectID
            }
        }
    }
}

// MARK: - AddCategoryPill
private struct AddCategoryPill: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label("Add", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(DS.Colors.chipFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Category")
    }
}

// MARK: - CategoryChip
private struct CategoryChip: View {
    let name: String
    let colorHex: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Circle()
                .fill(Color(hex: colorHex) ?? .secondary)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? DS.Colors.chipSelectedFill : DS.Colors.chipFill)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? DS.Colors.chipSelectedStroke : DS.Colors.chipFill, lineWidth: isSelected ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
