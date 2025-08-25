import Foundation
import CoreData

// MARK: - AddIncomeFormViewModel
/// Observable state + persistence for AddIncomeFormView.
/// Handles: loading existing income (edit), validation, and save to Core Data.
///
/// Properties:
/// - `isEditing`: toggled when an incomeObjectID is supplied
/// - `isPlanned`: planned vs actual
/// - `source`: text field
/// - `amountInput`: raw user input string for the amount (so we can show a prompt and left-align)
/// - `firstDate`: posting date
/// - `budgetObjectID`: retained for API compatibility (unused by current model)
///
/// Methods:
/// - `save(in:)` → creates/updates an `Income` managed object
@MainActor
final class AddIncomeFormViewModel: ObservableObject {

    // MARK: Inputs / Identity
    let incomeObjectID: NSManagedObjectID?
    let budgetObjectID: NSManagedObjectID?

    /// Retains the original income when editing.
    private var originalIncome: Income?

    // MARK: Editing State
    @Published var isEditing: Bool = false

    // MARK: Core Fields
    @Published var isPlanned: Bool = true
    @Published var source: String = ""
    /// String-backed amount so the field can show a real prompt instead of "$0.00".
    @Published var amountInput: String = ""
    @Published var firstDate: Date = Date()

    // MARK: Recurrence
    @Published var recurrenceRule: RecurrenceRule = .none
    /// Trigger for presenting the custom recurrence editor.
    @Published var isPresentingCustomRecurrenceEditor: Bool = false
    /// Seed for the custom recurrence editor.
    var customRuleSeed: CustomRecurrence = .init()

    /// Flag indicating whether the loaded income belongs to a series.
    var isPartOfSeries: Bool {
        if let inc = originalIncome {
            if inc.parentID != nil { return true }
            if let r = inc.recurrence, !r.isEmpty { return true }
        }
        return false
    }

    // MARK: Currency
    /// Resolve from Locale; override if you support per-budget/per-user currency.
    var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: Validation
    var canSave: Bool {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedSource.isEmpty && (parsedAmount ?? 0) > 0
    }

    // MARK: Init
    init(incomeObjectID: NSManagedObjectID?, budgetObjectID: NSManagedObjectID?) {
        self.incomeObjectID = incomeObjectID
        self.budgetObjectID = budgetObjectID
        self.isEditing = (incomeObjectID != nil)
    }

    // MARK: Load
    /// Loads existing `Income` into state if editing. Safe no-op if object cannot be fetched.
    func loadIfNeeded(from context: NSManagedObjectContext) throws {
        guard isEditing, let objectID = incomeObjectID else { return }
        // If we've already loaded the original income, avoid overwriting user edits
        guard originalIncome == nil else { return }
        guard let income = try context.existingObject(with: objectID) as? Income else { return }

        self.originalIncome = income

        self.isPlanned = income.isPlanned
        self.source = income.source ?? ""
        self.firstDate = income.date ?? Date()

        // Amount → present as a plain localized decimal string (not currency) for easier typing
        self.amountInput = formatAmountForEditing(income.amount)

        // Recurrence
        if let rec = income.recurrence, !rec.isEmpty {
            let second = Self.optionalInt16IfAttributeExists(on: income, keyCandidates: ["secondPayDay", "secondBiMonthlyPayDay"]) ?? 0
            self.recurrenceRule = RecurrenceRule.parse(from: rec,
                                                       endDate: income.recurrenceEndDate,
                                                       secondBiMonthlyPayDay: Int(second)) ?? .custom(rec, endDate: income.recurrenceEndDate)
            if case .custom(let raw, _) = recurrenceRule {
                self.customRuleSeed = CustomRecurrence.roughParse(rruleString: raw)
            }
        }
    }

    // MARK: Save
    /// Creates or updates an `Income` managed object using current state.
    /// - Parameters:
    ///   - context: Core Data context to use.
    ///   - scope: Recurrence propagation when editing an existing series.
    /// - Throws: Any Core Data error during save (with detailed, user-friendly message).
    func save(in context: NSManagedObjectContext, scope: RecurrenceScope = .all) throws {
        // Ensure edit state loaded if needed
        try loadIfNeeded(from: context)

        guard let amount = parsedAmount, amount > 0 else {
            throw ValidationError.invalidAmount
        }
        let service = IncomeService()
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let built = recurrenceRule.toRRule(starting: firstDate)
        let secondDay: Int16? = {
            guard let built = built, built.secondBiMonthlyPayDay > 0 else { return nil }
            return Int16(built.secondBiMonthlyPayDay)
        }()

        if isEditing, let income = originalIncome {
            try service.updateIncome(income,
                                    source: trimmedSource,
                                    amount: amount,
                                    date: firstDate,
                                    isPlanned: isPlanned,
                                    recurrence: built?.string,
                                    recurrenceEndDate: built?.until,
                                    secondBiMonthlyDay: secondDay,
                                    scope: scope)
        } else {
            _ = try service.createIncome(source: trimmedSource,
                                         amount: amount,
                                         date: firstDate,
                                         isPlanned: isPlanned,
                                         recurrence: built?.string,
                                         recurrenceEndDate: built?.until,
                                         secondBiMonthlyDay: secondDay)
        }
    }

    // MARK: Parsing & Formatting
    /// Parses `amountInput` to a Double using the current Locale’s decimal separators.
    private var parsedAmount: Double? {
        parseAmount(from: amountInput)
    }

    /// Convert a stored Double to a user-friendly editable string (locale-aware, no currency symbol).
    private func formatAmountForEditing(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? ""
    }

    /// Parse a string into Double using a tolerant, locale-aware NumberFormatter.
    private func parseAmount(from string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal

        // Attempt direct parse first
        if let num = nf.number(from: trimmed) {
            return num.doubleValue
        }

        // Fallback: strip currency symbols/whitespace and retry
        let symbols = CharacterSet(charactersIn: Locale.current.currencySymbol ?? "$")
        let cleaned = trimmed.components(separatedBy: symbols).joined()
        if let num2 = nf.number(from: cleaned) {
            return num2.doubleValue
        }

        // Last resort: replace commas with dots (or vice versa) and retry
        let alt: String
        if nf.decimalSeparator == "," {
            alt = cleaned.replacingOccurrences(of: ".", with: ",")
        } else {
            alt = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        return nf.number(from: alt)?.doubleValue
    }

    // MARK: Errors
    enum ValidationError: LocalizedError {
        case invalidAmount
        var errorDescription: String? {
            switch self {
            case .invalidAmount: return "Please enter a valid amount greater than 0."
            }
        }
    }

    // MARK: - Safe KVC helpers for schema drift
    private static func optionalInt16IfAttributeExists(on object: NSManagedObject,
                                                       keyCandidates: [String]) -> Int16? {
        for key in keyCandidates {
            if object.entity.attributesByName.keys.contains(key) {
                return object.value(forKey: key) as? Int16
            }
        }
        return nil
    }
}
