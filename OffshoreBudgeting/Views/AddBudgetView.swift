//
//  AddBudgetView.swift
//  SoFar
//
//  Cross-platform Add/Edit Budget form.
//  - Name text field
//  - Start/End date pickers
//  - Toggle list of Cards to track in this budget
//  - Toggle list of global Planned Expense presets to clone
//  - Save/Cancel actions (standardized via EditSheetScaffold)
//
//  Notes:
//  - ViewModel preloads synchronously in init when editing, so first frame is not blank.
//  - We still call `.task { await vm.load() }` to hydrate lists and refresh state.
//

import SwiftUI
import CoreData

// MARK: - AddBudgetView
struct AddBudgetView: View {

    // MARK: Environment
    /// We don't call `dismiss()` directly anymore (the scaffold handles it),
    /// but we keep this in case future platform-specific work needs it.
    @Environment(\.dismiss) private var dismiss

    // MARK: Inputs
    private let initialStartDate: Date?
    private let initialEndDate: Date?
    private let editingBudgetObjectID: NSManagedObjectID?
    private let onSaved: (() -> Void)?

    // MARK: VM
    @StateObject private var vm: AddBudgetViewModel

    // MARK: Local UI State
    /// Populated if saving fails; presented in a SwiftUI alert.
    @State private var saveErrorMessage: String?

    // MARK: Init (ADD)
    /// Use this initializer when **adding** a budget.
    /// - Parameters:
    ///   - initialStartDate: Suggested budget start date to prefill.
    ///   - initialEndDate: Suggested budget end date to prefill.
    ///   - onSaved: Callback fired after a successful save.
    init(
        initialStartDate: Date,
        initialEndDate: Date,
        onSaved: (() -> Void)? = nil
    ) {
        self.initialStartDate = initialStartDate
        self.initialEndDate = initialEndDate
        self.editingBudgetObjectID = nil
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: AddBudgetViewModel(
            startDate: initialStartDate,
            endDate: initialEndDate,
            editingBudgetObjectID: nil
        ))
    }

    // MARK: Init (EDIT)
    /// Use this initializer when **editing** an existing budget.
    /// - Parameters:
    ///   - editingBudgetObjectID: ObjectID for the Budget being edited.
    ///   - fallbackStartDate: Date to display *until* the real value is preloaded (very brief).
    ///   - fallbackEndDate: Date to display *until* the real value is preloaded (very brief).
    ///   - onSaved: Callback fired after a successful save.
    init(
        editingBudgetObjectID: NSManagedObjectID,
        fallbackStartDate: Date,
        fallbackEndDate: Date,
        onSaved: (() -> Void)? = nil
    ) {
        self.initialStartDate = fallbackStartDate
        self.initialEndDate = fallbackEndDate
        self.editingBudgetObjectID = editingBudgetObjectID
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: AddBudgetViewModel(
            startDate: fallbackStartDate,
            endDate: fallbackEndDate,
            editingBudgetObjectID: editingBudgetObjectID
        ))
    }

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            // MARK: Standardized Sheet Chrome
            title: vm.isEditing ? "Edit Budget" : "Add Budget",
            detents: [.medium, .large],
            saveButtonTitle: vm.isEditing ? "Save Changes" : "Create Budget",
            isSaveEnabled: vm.canSave,
            onSave: { saveTapped() }          // return true to dismiss
        ) {
            // MARK: Form Content (standardized)
            // Put only the fields inside; the scaffold wraps this in a Form and toolbar.

            // ---- Name
            UBFormSection("Name", isUppercased: true) {
                // Use an empty label with a prompt so the text acts as a
                // placeholder across platforms.  We expand the field to fill
                // the row and align text to the leading edge for consistency
                // with Add Card and the expense forms.
                UBFormRow {
                    TextField(
                        "",
                        text: $vm.budgetName,
                        prompt: Text(vm.defaultBudgetName)
                    )
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Budget Name")
                }
            }

            // ---- Dates
            UBFormSection("Dates", isUppercased: true) {
                HStack(spacing: DS.Spacing.m) {
                    DatePicker("Start", selection: $vm.startDate, displayedComponents: [.date])
                        .labelsHidden()
                        .ub_compactDatePickerStyle()
                    DatePicker("End", selection: $vm.endDate, displayedComponents: [.date])
                        .labelsHidden()
                        .ub_compactDatePickerStyle()
                }
            }

            // ---- Cards to Track
            UBFormSection("Cards to Track", isUppercased: true) {
                if vm.allCards.isEmpty {
                    Text("No cards yet. Add cards first to track variable expenses.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.allCards, id: \.objectID) { card in
                        let isTracking = Binding(
                            get: { vm.selectedCardObjectIDs.contains(card.objectID) },
                            set: { newValue in
                                if newValue {
                                    vm.selectedCardObjectIDs.insert(card.objectID)
                                } else {
                                    vm.selectedCardObjectIDs.remove(card.objectID)
                                }
                            }
                        )
                        Toggle(card.name ?? "Untitled Card", isOn: isTracking)
                    }
                }
            }

            // ---- Preset Planned Expenses
            UBFormSection("Preset Planned Expenses", isUppercased: true) {
                if vm.globalPlannedExpenseTemplates.isEmpty {
                    Text("No presets yet. You can add them later.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.globalPlannedExpenseTemplates, id: \.objectID) { template in
                        let isSelected = Binding(
                            get: { vm.selectedTemplateObjectIDs.contains(template.objectID) },
                            set: { newValue in
                                if newValue {
                                    vm.selectedTemplateObjectIDs.insert(template.objectID)
                                } else {
                                    vm.selectedTemplateObjectIDs.remove(template.objectID)
                                }
                            }
                        )
                        Toggle(template.descriptionText ?? "Untitled", isOn: isSelected)
                    }
                }
            }
        }
        // Keep async hydration for lists/templates.
        .task { await vm.load() }
        // Present any save error in a standard alert.
        .alert("Couldn’t Save Budget",
               isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    // MARK: Actions
    /// Attempts to save via the view model.
    /// - Returns: `true` to allow the scaffold to dismiss the sheet; `false` to keep it open.
    private func saveTapped() -> Bool {
        do {
            try vm.save()
            onSaved?()
            // Resign keyboard on iOS/iPadOS via unified helper for a neat dismissal.
            ub_dismissKeyboard()
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }
}
