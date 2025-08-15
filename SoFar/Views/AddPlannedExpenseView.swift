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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {

                    // MARK: Budget Picker (horizontal)
                    Text("Choose Budget")
                        .font(.headline)
                        .padding(.horizontal, DS.Spacing.l)

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

                    // MARK: Fields
                    VStack(spacing: DS.Spacing.m) {
                        TextField("Expense Description", text: $vm.descriptionText)
                            .textFieldStyle(.roundedBorder)
                            .ub_noAutoCapsAndCorrection()

                        TextField("Planned Amount", text: $vm.plannedAmountString)
                            .textFieldStyle(.roundedBorder)
                            .ub_decimalKeyboard()

                        TextField("Actual Amount", text: $vm.actualAmountString)
                            .textFieldStyle(.roundedBorder)
                            .ub_decimalKeyboard()

                        HStack {
                            Text("Transaction Date").font(.headline)
                            Spacer()
                            DatePicker("", selection: $vm.transactionDate, displayedComponents: [.date])
                                .labelsHidden()
                                .ub_compactDatePickerStyle()
                        }

                        // MARK: Use in future budgets?
                        Toggle("Use in future budgets?", isOn: $vm.saveAsGlobalPreset)
                    }
                    .padding(.horizontal, DS.Spacing.l)
                }
                .padding(.top, DS.Spacing.m)
            }
        }
        .navigationTitle("Add Planned Expense")
        .appToolbar(titleDisplayMode: .inline, trailingItems: [])
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") { trySave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canSave)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)
            .background(.ultraThinMaterial)
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
    /// Attempts to save; on success calls `onSaved` and dismisses.
    private func trySave() {
        guard vm.canSave else { return }
        do {
            try vm.save()
            onSaved()
            dismiss()
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
        }
    }
}
