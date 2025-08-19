//
//  AddUnplannedExpenseViewModel.swift
//  SoFar
//
//  Handles adding an UnplannedExpense to a selected Card.
//  Allows picking an ExpenseCategory.
//

import Foundation
import CoreData

// MARK: - AddUnplannedExpenseViewModel
@MainActor
final class AddUnplannedExpenseViewModel: ObservableObject, RecurrenceHandling {

    // MARK: Dependencies
    private let context: NSManagedObjectContext

    // MARK: Identity
    private let unplannedExpenseID: NSManagedObjectID?
    let isEditing: Bool

    // MARK: Loaded Data
    @Published private(set) var allCards: [Card] = []
    @Published private(set) var allCategories: [ExpenseCategory] = []

    // MARK: Allowed filter (e.g., only cards tracked by a given budget)
    private let allowedCardIDs: Set<NSManagedObjectID>?

    // MARK: Form State
    @Published var selectedCardID: NSManagedObjectID?
    @Published var selectedCategoryID: NSManagedObjectID?
    @Published var descriptionText: String = ""
    @Published var amountString: String = ""
    @Published var transactionDate: Date = Date()

    // MARK: Recurrence
    @Published var recurrenceRule: RecurrenceRule = .none
    var customRuleSeed: CustomRecurrence = CustomRecurrence()

    // MARK: Init
    init(unplannedExpenseID: NSManagedObjectID? = nil,
         allowedCardIDs: Set<NSManagedObjectID>? = nil,
         initialDate: Date? = nil,
         context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.unplannedExpenseID = unplannedExpenseID
        self.allowedCardIDs = allowedCardIDs
        self.context = context
        self.isEditing = unplannedExpenseID != nil
        if let d = initialDate { self.transactionDate = d }
    }

    // MARK: load()
    func load() async {
        CoreDataService.shared.ensureLoaded()
        allCards = fetchCards()
        allCategories = fetchCategories()

        if isEditing, let id = unplannedExpenseID,
           let existing = try? context.existingObject(with: id) as? UnplannedExpense {
            selectedCardID = existing.card?.objectID
            selectedCategoryID = existing.expenseCategory?.objectID
            descriptionText = existing.descriptionText ?? ""
            amountString = formatAmount(existing.amount)
            transactionDate = existing.transactionDate ?? Date()

            // Recurrence
            let rruleString = existing.recurrence ?? ""
            let end = existing.recurrenceEndDate
            let secondDay = (existing.value(forKey: "secondBiMonthlyDate") as? Int16).map { Int($0) } ?? 0
            if rruleString.isEmpty {
                recurrenceRule = .none
            } else if let parsed = RecurrenceRule.parse(from: rruleString, endDate: end, secondBiMonthlyPayDay: secondDay) {
                recurrenceRule = parsed
            } else {
                recurrenceRule = .custom(rruleString, endDate: end)
            }
            customRuleSeed = CustomRecurrence.roughParse(rruleString: rruleString)
        } else {
            // Default selections
            if selectedCardID == nil { selectedCardID = allCards.first?.objectID }
            if selectedCategoryID == nil { selectedCategoryID = allCategories.first?.objectID }
        }
    }

    // MARK: Validation
    var canSave: Bool {
        selectedCardID != nil
        && selectedCategoryID != nil
        && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (parsedAmount != nil)
    }

    // MARK: Parsed Amount
    /// Accepts either "." or "," as decimal separator and trims spaces.
    private var parsedAmount: Double? {
        let cleaned = amountString
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != ".", let value = Double(cleaned) else { return nil }
        return value
    }

    // MARK: save()
    func save() throws {
        // Resolve Card using existingObject(with:) so we fail fast if it’s invalid.
        guard
            let cardID = selectedCardID,
            let card = try context.existingObject(with: cardID) as? Card
        else {
            throw NSError(domain: "SoFar.AddUnplannedExpense", code: 10, userInfo: [NSLocalizedDescriptionKey: "Please select a card."])
        }

        // Resolve Category the same way (prevents temp-ID issues).
        guard
            let categoryID = selectedCategoryID,
            let category = try context.existingObject(with: categoryID) as? ExpenseCategory
        else {
            throw NSError(domain: "SoFar.AddUnplannedExpense", code: 11, userInfo: [NSLocalizedDescriptionKey: "Please select a category."])
        }

        guard let amt = parsedAmount, amt >= 0.01 else {
            throw NSError(domain: "SoFar.AddUnplannedExpense", code: 12, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid amount."])
        }

        let item: UnplannedExpense
        if let id = unplannedExpenseID,
           let existing = try? context.existingObject(with: id) as? UnplannedExpense {
            item = existing
        } else {
            item = UnplannedExpense(context: context)
            item.id = item.id ?? UUID()
        }

        item.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        item.amount = amt
        item.transactionDate = transactionDate
        item.card = card
        item.expenseCategory = category

        // Recurrence
        let rrule = recurrenceRule.toRRule(starting: transactionDate)
        item.recurrence = rrule?.string
        item.recurrenceEndDate = rrule?.until
        if let second = rrule?.secondBiMonthlyPayDay,
           item.entity.propertiesByName.keys.contains("secondBiMonthlyDate") {
            item.setValue(Int16(second), forKey: "secondBiMonthlyDate")
        }

        // Optional: support a boolean "isRecurring" if it exists in your model
        if let hasRecurring = item.entity.propertiesByName["isRecurring"] as? NSAttributeDescription {
            // default false unless UI added later
            item.setValue(item.value(forKey: hasRecurring.name) ?? false, forKey: hasRecurring.name)
        }

        try context.save()

        // Refresh in-memory caches so the form’s labels reflect saved data on return
        allCategories = fetchCategories()
        allCards = fetchCards()
    }

    // MARK: Private fetch
    private func fetchCards() -> [Card] {
        let req = NSFetchRequest<Card>(entityName: "Card")
        req.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        let cards = (try? context.fetch(req)) ?? []
        guard let allowed = allowedCardIDs, !allowed.isEmpty else { return cards }
        return cards.filter { allowed.contains($0.objectID) }
    }

    private func fetchCategories() -> [ExpenseCategory] {
        let req = NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
        req.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    private func formatAmount(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? ""
    }
}
