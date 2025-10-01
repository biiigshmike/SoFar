// OffshoreBudgeting/Views/AddIncomeFormView.swift

import SwiftUI
import CoreData

// MARK: - AddIncomeFormView
struct AddIncomeFormView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) private var dismiss

    let incomeObjectID: NSManagedObjectID?
    let budgetObjectID: NSManagedObjectID?
    let initialDate: Date?

    @StateObject var viewModel: AddIncomeFormViewModel
    @State private var error: SaveError?
    @State private var showEditScopeOptions: Bool = false

    init(incomeObjectID: NSManagedObjectID? = nil,
         budgetObjectID: NSManagedObjectID? = nil,
         initialDate: Date? = nil) {
        self.incomeObjectID = incomeObjectID
        self.budgetObjectID = budgetObjectID
        self.initialDate = initialDate
        _viewModel = StateObject(wrappedValue: AddIncomeFormViewModel(
            incomeObjectID: incomeObjectID,
            budgetObjectID: budgetObjectID
        ))
    }

    var body: some View {
        EditSheetScaffold(
            title: viewModel.isEditing ? "Edit Income" : "Add Income",
            detents: [.medium, .large],
            saveButtonTitle: viewModel.isEditing ? "Save Changes" : "Add Income",
            isSaveEnabled: viewModel.canSave,
            onSave: { saveTapped() }
        ) {
            Group {
                if viewModel.isEditing && viewModel.isPartOfSeries {
                    Text("Editing a recurring income. Choosing \"Edit this and all future instances\" will create a new series. Changes from this point forward will be treated as a new series.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
                typeSection
                sourceSection
                amountSection
                firstDateSection
                recurrenceSection
            }
        }
        .onAppear {
            do { try viewModel.loadIfNeeded(from: viewContext) }
            catch { /* This error is handled at save time */ }
            if !viewModel.isEditing, let prefill = initialDate {
                viewModel.firstDate = prefill
            }
        }
        .alert(item: $error) { err in
            Alert(
                title: Text("Couldn’t Save"),
                message: Text(err.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .ub_onChange(of: viewModel.isPresentingCustomRecurrenceEditor) { newValue in
            if newValue {
                if case .custom(let raw, _) = viewModel.recurrenceRule {
                    viewModel.customRuleSeed = CustomRecurrence.roughParse(rruleString: raw)
                } else {
                    viewModel.customRuleSeed = CustomRecurrence()
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCustomRecurrenceEditor) {
            CustomRecurrenceEditorView(initial: viewModel.customRuleSeed) {
                viewModel.isPresentingCustomRecurrenceEditor = false
            } onSave: { custom in
                viewModel.applyCustomRecurrence(custom)
                viewModel.isPresentingCustomRecurrenceEditor = false
            }
        }
        .confirmationDialog(
            "Update Recurring Income",
            isPresented: $showEditScopeOptions,
            titleVisibility: .visible
        ) {
            Button("Edit only this instance") { _ = performSave(scope: .instance) }
            Button("Edit this and all future instances (creates a new series)") { _ = performSave(scope: .future) }
            Button("Edit all instances (past and future)") { _ = performSave(scope: .all) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selecting \"Edit this and all future instances\" creates a new series. Changes from this point forward will be treated as a new series.")
        }
    }

    @ViewBuilder
    private var typeSection: some View {
        UBFormSection("Type", isUppercased: true) {
            PillSegmentedControl(selection: $viewModel.isPlanned) {
                Text("Planned").tag(true)
                Text("Actual").tag(false)
            }
            .accessibilityIdentifier("incomeTypeSegmentedControl")
        }
    }
    
    // ... (Rest of file is unchanged)
    @ViewBuilder
    private var sourceSection: some View {
        UBFormSection("Source", isUppercased: true) {
            UBFormRow {
                if #available(iOS 15.0, macCatalyst 15.0, *) {
                    TextField("", text: $viewModel.source, prompt: Text("Paycheck"))
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Income Source")
                } else {
                    TextField("Paycheck", text: $viewModel.source)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Income Source")
                }
            }
        }
    }
    @ViewBuilder
    private var amountSection: some View {
        UBFormSection("Amount", isUppercased: true) {
            UBFormRow {
                if #available(iOS 15.0, macCatalyst 15.0, *) {
                    TextField("", text: $viewModel.amountInput, prompt: Text("1000"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Income Amount")
                } else {
                    TextField("1542.75", text: $viewModel.amountInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Income Amount")
                }
            }
        }
    }
    @ViewBuilder
    private var firstDateSection: some View {
        UBFormSection("Entry Date", isUppercased: true) {
            DatePicker("", selection: $viewModel.firstDate, displayedComponents: [.date])
                .labelsHidden()
                .ub_compactDatePickerStyle()
                .accessibilityIdentifier("incomeFirstDatePicker")
                .accessibilityLabel("Entry Date")
        }
    }
    @ViewBuilder
    private var recurrenceSection: some View {
        UBFormSection("Recurrence", isUppercased: true) {
            RecurrencePickerView(rule: $viewModel.recurrenceRule,
                                 isPresentingCustomEditor: $viewModel.isPresentingCustomRecurrenceEditor)
        }
    }
    private func saveTapped() -> Bool {
        if viewModel.isEditing && viewModel.isPartOfSeries {
            showEditScopeOptions = true
            return false
        }
        return performSave(scope: .all)
    }
    private func performSave(scope: RecurrenceScope) -> Bool {
        do {
            try viewModel.save(in: viewContext, scope: scope)
            ub_dismissKeyboard()
            dismiss()
            return true
        } catch let err as SaveError {
            self.error = err
            return false
        } catch {
            self.error = .message("Unexpected error: \(error.localizedDescription)")
            return false
        }
    }
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
