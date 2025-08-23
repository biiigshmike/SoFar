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
/// - `firstDate`: posting date for the first occurrence
/// - `recurrenceRule`: selected recurrence (to RRULE string + optional end date)
/// - `budgetObjectID`: retained for API compatibility (unused by current model)
///
/// Methods:
/// - `save(in:)` → creates/updates an `Income` managed object
@MainActor
final class AddIncomeFormViewModel: ObservableObject {

    // MARK: Inputs / Identity
    let incomeObjectID: NSManagedObjectID?
    let budgetObjectID: NSManagedObjectID?

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
    /// Exposes a simple seed model for CustomRecurrenceEditor
    var customRuleSeed: CustomRecurrence = CustomRecurrence()

    // Retain parentID of original income to detect series membership
    private var originalParentID: UUID? = nil

    var isPartOfSeries: Bool {
        return originalParentID != nil || !(recurrenceRule == .none)
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
        guard let income = try context.existingObject(with: objectID) as? Income else { return }

        self.isPlanned = income.isPlanned
        self.source = income.source ?? ""
        self.firstDate = income.date ?? Date()

        // Amount → present as a plain localized decimal string (not currency) for easier typing
        self.amountInput = formatAmountForEditing(income.amount)

        // Map recurrence string → RecurrenceRule (best-effort)
        let rruleString = income.recurrence ?? ""
        let endDate = income.recurrenceEndDate

        if rruleString.isEmpty {
            self.recurrenceRule = .none
        } else if let parsed = RecurrenceRule.parse(from: rruleString, endDate: endDate, secondBiMonthlyPayDay: 0) {
            self.recurrenceRule = parsed
        } else {
            // Fallback to custom if unrecognized
            self.recurrenceRule = .custom(rruleString, endDate: endDate)
        }

        // Seed the custom editor roughly from existing rule (best-effort)
        self.customRuleSeed = CustomRecurrence.roughParse(rruleString: rruleString)

        // Remember original parentID
        self.originalParentID = income.parentID
    }

    // MARK: Save
    /// Creates or updates an `Income` managed object using current state.
    /// - Parameter context: Core Data context to use.
    /// - Throws: Any Core Data error during save (with detailed, user-friendly message).
    func save(in context: NSManagedObjectContext, scope: IncomeService.RecurrenceScope = .all) throws {
        // Ensure edit state loaded if needed
        try loadIfNeeded(from: context)

        guard let amount = parsedAmount, amount > 0 else {
            throw ValidationError.invalidAmount
        }

        // Always save on the context's queue so we don't trip concurrency protections.
        var thrown: Error?
        context.performAndWait {
            do {
                if let objectID = incomeObjectID,
                   let existing = try? context.existingObject(with: objectID) as? Income {
                    let rrule = recurrenceRule.toRRule(starting: firstDate)
                    switch scope {
                    case .all, .thisAndFuture:
                        try IncomeService(stack: CoreDataService.shared).updateIncome(existing,
                                                                                     scope: scope,
                                                                                     source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                                     amount: amount,
                                                                                     date: firstDate,
                                                                                     isPlanned: isPlanned,
                                                                                     recurrence: rrule?.string,
                                                                                     recurrenceEndDate: rrule?.until,
                                                                                     secondBiMonthlyDay: nil)
                    case .onlyThis:
                        existing.isPlanned = isPlanned
                        existing.source = source.trimmingCharacters(in: .whitespacesAndNewlines)
                        existing.amount = amount
                        existing.date = firstDate
                        let rrule = recurrenceRule.toRRule(starting: firstDate)
                        existing.recurrence = rrule?.string ?? ""
                        existing.recurrenceEndDate = rrule?.until
                        try context.save()
                    }
                } else {
                    let rrule = recurrenceRule.toRRule(starting: firstDate)
                    let _ = try IncomeService(stack: CoreDataService.shared).createIncome(source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                                         amount: amount,
                                                                                         date: firstDate,
                                                                                         isPlanned: isPlanned,
                                                                                         recurrence: rrule?.string,
                                                                                         recurrenceEndDate: rrule?.until,
                                                                                         secondBiMonthlyDay: nil)
                }
            } catch let nsError as NSError {
                thrown = SaveError.coreData(nsError).asPublicError()
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }
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
}
