import SwiftUI
import CoreData

// MARK: - AddIncomeFormView
/// A standardized add/edit sheet for Planned or Actual income entries.
/// Mirrors the visual chrome and labeling of AddBudgetFormView / AddCardView.
/// Usage:
///     - Provide an optional `incomeObjectID` to edit an existing Income; otherwise a new record is created.
///     - Optionally pass `budgetObjectID` to associate the income to a specific budget on save.
///     - The Save button is enabled when Source is non-empty and Amount > 0.
struct AddIncomeFormView: View {
    // MARK: Environment
    @Environment(\.managedObjectContext) var viewContext   // internal so lifecycle extension can access
    @Environment(\.dismiss) private var dismiss

    // MARK: Inputs
    /// If non-nil, loads and edits an existing Income object.
    let incomeObjectID: NSManagedObjectID?
    /// Optional Budget to attach this income to on save (currently unused by the model).
    let budgetObjectID: NSManagedObjectID?
    /// If provided (from calendar or + button), pre-fills the 'First Date' field when adding.
    /// Must be internal so the lifecycle extension in a separate file can read it.
    let initialDate: Date?

    // MARK: State
    /// Must be internal so the lifecycle extension in a separate file can call into it.
    @StateObject var viewModel: AddIncomeFormViewModel = AddIncomeFormViewModel(incomeObjectID: nil, budgetObjectID: nil)
    @State private var error: SaveError?
    @State private var showEditScopeOptions: Bool = false

    // MARK: Init
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

    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            // MARK: Standardized Sheet Chrome
            title: viewModel.isEditing ? "Edit Income" : "Add Income",
            detents: [.medium, .large],
            saveButtonTitle: viewModel.isEditing ? "Save Changes" : "Add Income",
            isSaveEnabled: viewModel.canSave,
            onSave: { saveTapped() } // return true to dismiss
        ) {
            // MARK: Form Content
            // Wrap in Group to help the scaffold infer its generic Content on macOS
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
        .alert(item: $error) { err in
            Alert(
                title: Text("Couldn’t Save"),
                message: Text(err.message),
                dismissButton: .default(Text("OK"))
            )
        }
        // MARK: Eager load (edit) / Prefill date (add)
        _eagerLoadHook
        .onChange(of: viewModel.isPresentingCustomRecurrenceEditor) { old, newValue in
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
        .confirmationDialog("Update Recurring Income", isPresented: $showEditScopeOptions, titleVisibility: {
            Text("Selecting \"Edit this and all future instances\" creates a new series. Changes from this point forward will be treated as a new series.")
        }) {
            Button("Edit only this instance") { _ = performSave(scope: .instance) }
            Button("Edit this and all future instances (creates a new series)") { _ = performSave(scope: .future) }
            Button("Edit all instances (past and future)") { _ = performSave(scope: .all) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sections

    // MARK: Type
    /// Segmented control to switch between Planned (true) and Actual (false).
    /// Fills the entire row on macOS/iOS.
    @ViewBuilder
    private var typeSection: some View {
        UBFormSection("Type", isUppercased: true) {
            // A stretching container ensures the row uses the full available width.
            HStack {
                Picker("", selection: $viewModel.isPlanned) {
                    Text("Planned").tag(true)
                    Text("Actual").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()                         // no inline label column
                .frame(maxWidth: .infinity)             // <- make the control stretch
                .controlSize(.large)                    // (optional) nicer tap targets
                .accessibilityIdentifier("incomeTypeSegmentedControl")
            }
            .frame(maxWidth: .infinity)                 // <- make the row stretch
        }
    }


    // MARK: Source
    /// Source of income, such as "Paycheck" or "Gift".  The section
    /// header appears outside the text field to match the Add Card and
    /// expense views.  The text field expands to fill the row and aligns
    /// the content to the leading edge.
    @ViewBuilder
    private var sourceSection: some View {
        UBFormSection("Source", isUppercased: true) {
            if #available(iOS 15.0, macOS 12.0, *) {
                TextField("", text: $viewModel.source, prompt: Text("Paycheck"))
                    .ub_noAutoCapsAndCorrection()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Income Source")
            } else {
                TextField("Paycheck", text: $viewModel.source)
                    .ub_noAutoCapsAndCorrection()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Income Source")
            }
        }
    }

    // MARK: Amount
    /// Monetary amount for the income.  The field uses the cross‑platform
    /// decimal keyboard helper and aligns its contents to the leading edge.
    @ViewBuilder
    private var amountSection: some View {
        UBFormSection("Amount", isUppercased: true) {
            if #available(iOS 15.0, macOS 12.0, *) {
                TextField("", text: $viewModel.amountInput, prompt: Text("1000"))
                    .ub_decimalKeyboard()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Income Amount")
            } else {
                TextField("1542.75", text: $viewModel.amountInput)
                    .ub_decimalKeyboard()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Income Amount")
            }
        }
    }

    // MARK: First Date
    /// The first date when this income is received.  The date picker label
    /// is hidden so the section header provides the context.  We use
    /// `.ub_compactDatePickerStyle()` for a consistent cross‑platform look.
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

    // MARK: Recurrence
    @ViewBuilder
    private var recurrenceSection: some View {
        UBFormSection("Recurrence", isUppercased: true) {
            RecurrencePickerView(rule: $viewModel.recurrenceRule,
                                 isPresentingCustomEditor: $viewModel.isPresentingCustomRecurrenceEditor)
        }
    }

    // MARK: Save
    /// Validates and persists. Returns `true` to dismiss the sheet.
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

    // MARK: Utilities
    /// Uniform section header style.
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
