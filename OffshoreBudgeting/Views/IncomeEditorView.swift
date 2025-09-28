//
//  IncomeEditorView.swift
//  SoFar
//
//  A standardized sheet using EditSheetScaffold to add or edit an Income.
//  Fields: Source, Amount, Date, Planned/Actual, Recurring? Frequency, End Date, Second Payday (for semi-monthly).
//

import SwiftUI
import CoreData

// MARK: - IncomeEditorMode
/// Controls how the editor behaves:
/// - `.add(Date)`: prefill the form with a specific date when creating a new income
/// - `.edit`: edit an existing `Income` (passed via `seedIncome`)
enum IncomeEditorMode: Equatable {
    case add(Date)
    case edit
}

// MARK: - IncomeEditorAction
/// Represents a user's action from the editor.
enum IncomeEditorAction {
    case created(source: String, amount: Double, date: Date, isPlanned: Bool,
                 recurrence: String?, recurrenceEndDate: Date?, secondBiMonthlyDay: Int16?)
    case updated(income: Income, source: String, amount: Double, date: Date, isPlanned: Bool,
                 recurrence: String?, recurrenceEndDate: Date?, secondBiMonthlyDay: Int16?)
    case cancelled
}

// MARK: - Editor Form Model
/// Holds all editor field values and derived helpers used by the view.
/// - `amountString` is kept as text for resilient typing, with `amountDouble` computed.
struct IncomeEditorForm {
    var source: String = ""
    var amountString: String = ""
    var date: Date = Date()
    var isPlanned: Bool = true
    
    // Recurrence
    var isRecurring: Bool = false
    var frequency: RecurrenceOption = .none
    var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var secondBiMonthlyDay: Int = 15
    
    // Derived
    var amountDouble: Double { Double(amountString.replacingOccurrences(of: ",", with: "")) ?? 0 }
    var recurrenceString: String? {
        switch frequency {
        case .none: return nil
        default: return frequency.rawValue
        }
    }
}

// MARK: RecurrenceOption
/// Frequency options for recurring income.
enum RecurrenceOption: String, CaseIterable, Identifiable {
    case none
    case weekly
    case biweekly
    case semimonthly
    case monthly
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "None"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .semimonthly: return "Twice Monthly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - IncomeEditorView
struct IncomeEditorView: View {
    // MARK: Inputs
    let mode: IncomeEditorMode
    let seedIncome: Income?
    let onCommit: (IncomeEditorAction) -> Bool   // return true to dismiss
    
    // MARK: Environment
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    // MARK: State
    @State private var form: IncomeEditorForm = .init()
    
    // MARK: Init
    /// - Parameters:
    ///   - mode: `.add(date)` to prefill the date; `.edit` to edit `seedIncome`
    ///   - seedIncome: the income to edit when in `.edit` mode
    ///   - onCommit: closure invoked on Save/Cancel; return `true` to dismiss the sheet
    init(mode: IncomeEditorMode, seedIncome: Income? = nil, onCommit: @escaping (IncomeEditorAction) -> Bool) {
        self.mode = mode
        self.seedIncome = seedIncome
        self.onCommit = onCommit
        _form = State(initialValue: Self.makeInitialForm(mode: mode, seed: seedIncome))
    }
    
    // MARK: Body
    var body: some View {
        EditSheetScaffold(
            title: titleText,
            detents: [.medium, .large],
            saveButtonTitle: saveButtonTitle,
            cancelButtonTitle: "Cancel",
            isSaveEnabled: canSave,
            onCancel: { _ = onCommit(.cancelled) },
            onSave: { handleSave() }
        ) {
            // MARK: Details
            Section {
                UBFormRow {
                    TextField("Paycheck", text: $form.source)
                        .ub_noAutoCapsAndCorrection()   // cross-platform fix
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                amountField
                DatePicker("Date", selection: $form.date, displayedComponents: .date)

                Picker("Type", selection: $form.isPlanned) {
                    Text("Planned").tag(true)
                    Text("Actual").tag(false)
                }
                .pickerStyle(.segmented)
                .ubSegmentedControlStyle(
                    capabilities: capabilities,
                    accentColor: themeManager.selectedTheme.glassPalette.accent
                )
            } header: {
                Text("Details")
            }
            
            // MARK: Recurrence
            Section {
                Toggle("Recurring?", isOn: $form.isRecurring.animation())
                if form.isRecurring {
                    Picker("Frequency", selection: $form.frequency) {
                        ForEach(RecurrenceOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if form.frequency != .none {
                        DatePicker("End Date", selection: $form.recurrenceEndDate, displayedComponents: .date)
                    }
                    
                    if form.frequency == .semimonthly {
                        Stepper("Second Payday: \(form.secondBiMonthlyDay)", value: $form.secondBiMonthlyDay, in: 1...28)
                            .help("For twice-monthly schedules, choose the second day of the month.")
                    }
                }
            } header: {
                Text("Recurrence")
            } footer: {
                if form.isRecurring && form.frequency != .none {
                    Text("Projected occurrences will appear on the calendar within the selected window.")
                }
            }
        }
    }
    
    // MARK: Labels
    private var titleText: String {
        switch mode {
        case .add: return "Add Income"
        case .edit: return "Edit Income"
        }
    }
    private var saveButtonTitle: String {
        switch mode {
        case .add: return "Save"
        case .edit: return "Save Changes"
        }
    }
    
    // MARK: Validation
    private var canSave: Bool {
        !form.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && form.amountDouble > 0
    }
    
    // MARK: Amount Field
    /// Right-aligned numeric entry with decimal keyboard on iOS; cross-platform safe.
    private var amountField: some View {
        HStack {
            Text("Amount")
            Spacer()
            TextField("0.00", text: $form.amountString)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        }
    }
    
    // MARK: Save Handler
    /// Validates and emits `.created` / `.updated`. Returns `true` to dismiss.
    @discardableResult
    private func handleSave() -> Bool {
        guard canSave else { return false }
        switch mode {
        case .add:
            let recurrence = form.recurrenceString
            let endDate = (form.isRecurring && form.frequency != .none) ? form.recurrenceEndDate : nil
            let secondDay: Int16? = (form.isRecurring && form.frequency == .semimonthly) ? Int16(form.secondBiMonthlyDay) : nil
            return onCommit(.created(source: form.source,
                                     amount: form.amountDouble,
                                     date: form.date,
                                     isPlanned: form.isPlanned,
                                     recurrence: recurrence,
                                     recurrenceEndDate: endDate,
                                     secondBiMonthlyDay: secondDay))
        case .edit:
            guard let inc = seedIncome else { return false }
            let recurrence = form.recurrenceString
            let endDate = (form.isRecurring && form.frequency != .none) ? form.recurrenceEndDate : nil
            let secondDay: Int16? = (form.isRecurring && form.frequency == .semimonthly) ? Int16(form.secondBiMonthlyDay) : nil
            return onCommit(.updated(income: inc,
                                     source: form.source,
                                     amount: form.amountDouble,
                                     date: form.date,
                                     isPlanned: form.isPlanned,
                                     recurrence: recurrence,
                                     recurrenceEndDate: endDate,
                                     secondBiMonthlyDay: secondDay))
        }
    }
    
    // MARK: Initial Form
    /// Builds initial field values based on mode and optional seed income.
    /// - Parameters:
    ///   - mode: `.add(date)` or `.edit`
    ///   - seed: existing `Income` to edit when in `.edit`
    private static func makeInitialForm(mode: IncomeEditorMode, seed: Income?) -> IncomeEditorForm {
        if case .edit = mode, let inc = seed {
            var f = IncomeEditorForm()
            f.source = inc.source ?? ""
            f.amountString = String(inc.amount)
            f.date = inc.date ?? Date()
            f.isPlanned = inc.isPlanned
            if let r = inc.recurrence, !r.isEmpty {
                f.isRecurring = true
                f.frequency = RecurrenceOption(rawValue: r.lowercased()) ?? .none
            } else {
                f.isRecurring = false
                f.frequency = .none
            }
            if let end = inc.recurrenceEndDate { f.recurrenceEndDate = end }
            // We cannot read secondBiMonthlyDay safely across schema variants; default for UI.
            f.secondBiMonthlyDay = 15
            return f
        } else if case .add(let date) = mode {
            var f = IncomeEditorForm()
            f.date = date
            return f
        } else {
            return IncomeEditorForm()
        }
    }
}
