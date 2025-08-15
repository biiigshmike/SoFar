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

    // MARK: Recurrence UI State (for Custom Editor sheet trigger)
    /// Controls presentation when the RecurrencePickerView asks the host to show a custom editor.
    @State private var isPresentingCustomRecurrenceEditor: Bool = false

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
                typeSection
                detailsSection
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
    }

    // MARK: Sections

    // MARK: Type
    /// Segmented control to switch between Planned (true) and Actual (false).
    /// Binding: `$viewModel.isPlanned` — true = Planned; false = Actual.
    @ViewBuilder
    private var typeSection: some View {
        Section {
            Picker("Type", selection: $viewModel.isPlanned) {
                Text("Planned").tag(true)
                Text("Actual").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("incomeTypeSegmentedControl")
        } header: {
            sectionHeader("Type")
        }
    }

    // MARK: Details
    /// Source, amount, and first date.
    @ViewBuilder
    private var detailsSection: some View {
        Section {
            // ---- Source
            TextField("e.g., Paycheck", text: $viewModel.source)
                .ub_noAutoCapsAndCorrection()

            // ---- Amount
            TextField("e.g., 1,234.56", text: $viewModel.amountInput)
            #if os(iOS)
                .keyboardType(.decimalPad)   // iOS only; gated so macOS compiles
            #endif

            // ---- First Date
            DatePicker("First Date", selection: $viewModel.firstDate, displayedComponents: [.date])
                .accessibilityIdentifier("incomeFirstDatePicker")
        } header: {
            sectionHeader("Details")
        }
    }

    // MARK: Recurrence
    /// Recurrence presets + options, including "forever" and end date.
    /// NOTE: `RecurrencePickerView` signature expects:
    ///   - rule: Binding<RecurrenceRule>
    ///   - isPresentingCustomEditor: Binding<Bool>
    @ViewBuilder
    private var recurrenceSection: some View {
        Section {
            RecurrencePickerView(
                rule: $viewModel.recurrenceRule,
                isPresentingCustomEditor: $isPresentingCustomRecurrenceEditor
            )
        } header: {
            sectionHeader("Recurrence (Optional)")
        }
    }

    // MARK: Save
    /// Validates and persists. Returns `true` to dismiss the sheet.
    private func saveTapped() -> Bool {
        do {
            try viewModel.save(in: viewContext) // NOTE: `in:` matches the VM’s signature
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
