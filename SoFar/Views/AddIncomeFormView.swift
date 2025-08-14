import SwiftUI
import CoreData

// MARK: - AddIncomeFormView
/// A standardized add/edit sheet for Planned or Actual income entries.
/// Mirrors the visual chrome and labeling of AddBudgetFormView / AddCardView.
/// Usage:
///     - Provide an optional `incomeObjectID` to edit an existing Income, otherwise a new record is created.
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

    // MARK: State
    @StateObject var viewModel: AddIncomeFormViewModel     // internal so lifecycle extension can access
    @State private var isPresentingCustomRecurrence = false
    @State private var error: IdentifiableError?

    // MARK: Init
    init(incomeObjectID: NSManagedObjectID? = nil,
         budgetObjectID: NSManagedObjectID? = nil) {
        self.incomeObjectID = incomeObjectID
        self.budgetObjectID = budgetObjectID
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
            typeSection
            detailsSection
            recurrenceSection
        }
        .alert(item: $error) { err in
            Alert(title: Text("Couldn’t Save"),
                  message: Text(err.message),
                  dismissButton: .default(Text("OK")))
        }
        // Attach the eager-load hook so editing forms prefill immediately.
        .background(_eagerLoadHook)
    }

    // MARK: Sections
    /// Planned vs Actual
    @ViewBuilder
    private var typeSection: some View {
        Section {
            Picker("Type", selection: $viewModel.isPlanned) {
                Text("Planned").tag(true)
                Text("Actual").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("incomeTypePicker")
        } header: {
            sectionHeader("Type")
        }
    }

    /// Source, Amount, First Date
    @ViewBuilder
    private var detailsSection: some View {
        Section {
            // ---- Source
            TextField("Source", text: $viewModel.source, prompt: Text("e.g., Paycheck"))
                .ub_noAutoCapsAndCorrection()
                .accessibilityIdentifier("incomeSourceField")

            // ---- Amount (String-backed so we can show a real prompt and left alignment)
            TextField("Amount",
                      text: $viewModel.amountInput,
                      prompt: Text("e.g., 2,500.00"))
                .ub_noAutoCapsAndCorrection()
                .multilineTextAlignment(.leading) // left align while typing
                .accessibilityIdentifier("incomeAmountField")
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif

            // ---- First Date
            DatePicker("First Date", selection: $viewModel.firstDate, displayedComponents: [.date])
                .accessibilityIdentifier("incomeFirstDatePicker")
        } header: {
            sectionHeader("Details")
        }
    }

    /// Recurrence presets + options, including "forever" and end date.
    @ViewBuilder
    private var recurrenceSection: some View {
        Section {
            RecurrencePickerView(
                rule: $viewModel.recurrenceRule,
                isPresentingCustomEditor: $isPresentingCustomRecurrence
            )
            .accessibilityIdentifier("incomeRecurrencePicker")
        } header: {
            sectionHeader("Recurrence")
        }
        .sheet(isPresented: $isPresentingCustomRecurrence) {
            CustomRecurrenceEditorView(
                initial: viewModel.customRuleSeed,
                onCancel: { isPresentingCustomRecurrence = false },
                onSave: { custom in
                    viewModel.applyCustomRecurrence(custom)
                    isPresentingCustomRecurrence = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Actions
    /// Attempts to save via the view model. Returns `true` to dismiss sheet; false keeps it open.
    @discardableResult
    private func saveTapped() -> Bool {
        do {
            try viewModel.save(in: viewContext)
            return true
        } catch {
            self.error = IdentifiableError(error.localizedDescription)
            return false
        }
    }

    // MARK: Helpers
    /// Small, consistent all-caps gray header like AddBudget/AddCard
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .textCase(.none) // ensure we control casing
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - IdentifiableError
/// Wraps an error message for SwiftUI .alert(item:)
private struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
    init(_ message: String) { self.message = message }
}
