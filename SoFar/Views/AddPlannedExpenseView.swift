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
    /// Called after a successful save.
    let onSaved: () -> Void

    // MARK: State
    /// We don't call `dismiss()` directly anymore (the scaffold handles it),
    /// but we keep this in case future platform-specific work needs it.
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AddPlannedExpenseViewModel

    /// Guard to apply `defaultSaveAsGlobalPreset` only once on first load.
    @State private var didApplyDefaultGlobal = false

    // MARK: Layout
    /// Height of the horizontal budget picker row.  We explicitly constrain
    /// the picker height so it doesn’t expand to fill excessive space on
    /// macOS sheets.  The height is slightly taller on iOS/iPadOS to account
    /// for larger touch targets.
    #if os(macOS)
    private let budgetPickerHeight: CGFloat = 100
    #else
    private let budgetPickerHeight: CGFloat = 110
    #endif

    // MARK: Init
    /// Designated initializer.
    /// - Parameters:
    ///   - preselectedBudgetID: Optional budget objectID to preselect.
    ///   - defaultSaveAsGlobalPreset: When true, defaults the "Use in future budgets?" toggle to ON on first load.
    ///   - onSaved: Closure invoked after `vm.save()` succeeds.
    init(
        plannedExpenseID: NSManagedObjectID? = nil,
        preselectedBudgetID: NSManagedObjectID? = nil,
        defaultSaveAsGlobalPreset: Bool = false,
        onSaved: @escaping () -> Void
    ) {
        self.plannedExpenseID = plannedExpenseID
        self.preselectedBudgetID = preselectedBudgetID
        self.defaultSaveAsGlobalPreset = defaultSaveAsGlobalPreset
        self.onSaved = onSaved
        _vm = StateObject(
            wrappedValue: AddPlannedExpenseViewModel(
                plannedExpenseID: plannedExpenseID,
                preselectedBudgetID: preselectedBudgetID
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
            // MARK: Budget Picker (horizontal)
            UBFormSection("Choose Budget", isUppercased: true) {
                // Horizontal picker of budgets.  Constrain the height explicitly
                // so the row doesn’t take up the majority of the sheet on macOS.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DS.Spacing.m) {
                        ForEach(vm.allBudgets, id: \.objectID) { budget in
                            SelectCard(
                                title: budget.name ?? "Untitled",
                                isSelected: vm.selectedBudgetID == budget.objectID
                            )
                            .onTapGesture { vm.selectedBudgetID = budget.objectID }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                }
                .frame(height: budgetPickerHeight)
                .ub_pickerBackground()
                .ub_hideScrollIndicators()
            }

            // MARK: Individual Fields
            // Instead of grouping all fields into a single section, mirror the
            // Add Card form by giving each input its own section with a
            // descriptive header.  This pushes the label outside of the cell
            // (e.g. “Name” in Add Card) and allows the actual `TextField`
            // to be empty, so the placeholder remains visible and left‑aligned.

            // Expense Description
            UBFormSection("Expense Description", isUppercased: true) {
                // Use an empty label and a prompt for true placeholder styling on modern OSes.
                if #available(iOS 15.0, macOS 12.0, *) {
                    TextField("", text: $vm.descriptionText, prompt: Text("Electric"))
                        .ub_noAutoCapsAndCorrection()
                        // Align text to the leading edge and make the field
                        // expand to fill available row width.  Without this,
                        // macOS tends to shrink the field and right‑align the
                        // placeholder.  The frame ensures left alignment on
                        // all platforms.
//                        .multilineTextAlignment(.leading)
//                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Expense Description")
                } else {
                    TextField("e.g., groceries", text: $vm.descriptionText)
                        .ub_noAutoCapsAndCorrection()
//                        .multilineTextAlignment(.leading)
//                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Expense Description")
                }
            }

            // Planned Amount
            UBFormSection("Planned Amount", isUppercased: true) {
                if #available(iOS 15.0, macOS 12.0, *) {
                    TextField("", text: $vm.plannedAmountString, prompt: Text("100"))
                        .ub_decimalKeyboard()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Planned Amount")
                } else {
                    TextField("e.g., 25.00", text: $vm.plannedAmountString)
                        .ub_decimalKeyboard()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Planned Amount")
                }
            }

            // Actual Amount
            UBFormSection("Actual Amount", isUppercased: true) {
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
        // Apply cross‑platform form styling and sheet padding
        .ub_formStyleGrouped()
        .ub_hideScrollIndicators()
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
}
