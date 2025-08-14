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
final class AddUnplannedExpenseViewModel: ObservableObject {

    // MARK: Dependencies
    private let context: NSManagedObjectContext

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

    // MARK: Init
    init(allowedCardIDs: Set<NSManagedObjectID>? = nil,
         initialDate: Date? = nil,
         context: NSManagedObjectContext = CoreDataService.shared.viewContext) {
        self.allowedCardIDs = allowedCardIDs
        self.context = context
        if let d = initialDate { self.transactionDate = d }
    }

    // MARK: load()
    func load() async {
        CoreDataService.shared.ensureLoaded()
        allCards = fetchCards()
        allCategories = fetchCategories()

        // Default selections
        if selectedCardID == nil { selectedCardID = allCards.first?.objectID }
        if selectedCategoryID == nil { selectedCategoryID = allCategories.first?.objectID }
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

        let newItem = UnplannedExpense(context: context)
        newItem.id = newItem.id ?? UUID()
        newItem.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        newItem.amount = amt
        newItem.transactionDate = transactionDate
        newItem.card = card
        newItem.expenseCategory = category

        // Optional: support a boolean "isRecurring" if it exists in your model
        if let hasRecurring = newItem.entity.propertiesByName["isRecurring"] as? NSAttributeDescription {
            // default false unless UI added later
            newItem.setValue(false, forKey: hasRecurring.name)
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
}
