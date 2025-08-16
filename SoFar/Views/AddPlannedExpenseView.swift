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
    /// Budget to preselect in the horizontal picker; pass nil to let the user choose.
    let preselectedBudgetID: NSManagedObjectID?
    /// New: if true, the "Use in future budgets?" toggle will start ON when the view first appears.
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

    // MARK: Init
    /// Designated initializer.
    /// - Parameters:
    ///   - preselectedBudgetID: Optional budget objectID to preselect.
    ///   - defaultSaveAsGlobalPreset: When true, defaults the "Use in future budgets?" toggle to ON on first load.
    ///   - onSaved: Closure invoked after `vm.save()` succeeds.
    init(
        preselectedBudgetID: NSManagedObjectID?,
        defaultSaveAsGlobalPreset: Bool = false,
        onSaved: @escaping () -> Void
    ) {
        self.preselectedBudgetID = preselectedBudgetID
        self.defaultSaveAsGlobalPreset = defaultSaveAsGlobalPreset
        self.onSaved = onSaved
        _vm = StateObject<AddPlannedExpenseViewModel>(
            wrappedValue: AddPlannedExpenseViewModel(preselectedBudgetID: preselectedBudgetID)
        )
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: "Add Planned Expense",
            saveButtonTitle: "Save",
            isSaveEnabled: vm.canSave,
            onSave: { trySave() }
        ) {
            // MARK: Budget Picker (horizontal)
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DS.Spacing.m) {
                        ForEach(vm.allBudgets, id: \.objectID) { b in
                            SelectCard(
                                title: b.name ?? "Untitled",
                                isSelected: vm.selectedBudgetID == b.objectID
                            )
                            .onTapGesture { vm.selectedBudgetID = b.objectID }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                }
            } header: {
                Text("Choose Budget")
            }

            // MARK: Fields
            Section {
                TextField("Expense Description", text: $vm.descriptionText)
                    .ub_noAutoCapsAndCorrection()

                TextField("Planned Amount", text: $vm.plannedAmountString)
                    .ub_decimalKeyboard()

                TextField("Actual Amount", text: $vm.actualAmountString)
                    .ub_decimalKeyboard()

                DatePicker("Transaction Date", selection: $vm.transactionDate, displayedComponents: [.date])
                    .ub_compactDatePickerStyle()
            }

            // MARK: Use in future budgets?
            Section {
                Toggle("Use in future budgets?", isOn: $vm.saveAsGlobalPreset)
            }
        }
        .task {
            // MARK: Lifecycle
            await vm.load()

            // Apply the default ONCE; do not fight the user's later toggle.
            if !didApplyDefaultGlobal {
                vm.saveAsGlobalPreset = defaultSaveAsGlobalPreset
                didApplyDefaultGlobal = true
            }
        }
    }

    // MARK: Actions
    /// Attempts to save; on success calls `onSaved`.
    /// - Returns: `true` if the sheet should dismiss, `false` to stay open.
    private func trySave() -> Bool {
        guard vm.canSave else { return false }
        do {
            try vm.save()
            onSaved()
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
            return true
        } catch {
            #if canImport(UIKit)
            let alert = UIAlertController(title: "Couldn’t Save", message: error.localizedDescription, preferredStyle: .alert)
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
