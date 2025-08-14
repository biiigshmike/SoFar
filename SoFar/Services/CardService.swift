//
//  CardService.swift
//  SoFar
//
//  Purpose: Manage CRUD for Card entities and handle their Budget linking.
//  Notes:
//  - Model (as of 2025-08-10 context):
//      Card: id (UUID), name (String)
//      Relationships: Card.budget <-> Budget.cards (many-to-many)
//  - This service is UI-agnostic and platform-agnostic (iOS, iPadOS, macOS).
//  - Uses CoreDataRepository for consistent CRUD patterns.
//  - Relationship edits use mutableSetValue(forKey:) for codegen-agnostic safety.
//  - Avoid direct `.id` property access to prevent ambiguity when Identifiable is also in play.
//
//  Usage examples:
//      let service = CardService()
//      let card = try service.createCard(name: "Chase Sapphire")
//      try service.renameCard(card, to: "Chase Sapphire Preferred")
//      try service.attachCard(card, toBudgetsWithIDs: [someBudgetID])
//      let cards = try service.fetchCards(forBudgetID: someBudgetID)
//      try service.deleteCard(card)
//

import Foundation
import CoreData

// MARK: - CardService
/// Public API to manage `Card` records.
final class CardService {
    
    // MARK: Properties
    /// Repository scoped to Card entity.
    private let cardRepo: CoreDataRepository<Card>
    /// A tiny side repo for Budget to resolve relationships by ID when needed.
    private let budgetRepo: CoreDataRepository<Budget>
    
    // MARK: Init
    /// Initialize the service. You can inject a custom CoreDataStackProviding for tests.
    /// - Parameter stack: Optional Core Data stack provider; defaults to CoreDataService.shared.
    init(stack: CoreDataStackProviding = CoreDataService.shared) {
        self.cardRepo = CoreDataRepository<Card>(stack: stack)
        self.budgetRepo = CoreDataRepository<Budget>(stack: stack)
    }
    
    // MARK: fetchAllCards(sortedByName:)
    /// Fetch all cards.
    /// - Parameter sortedByName: If true, returns A→Z by name (localized, case-insensitive).
    /// - Returns: Array of Card.
    func fetchAllCards(sortedByName: Bool = true) throws -> [Card] {
        let sort = sortedByName
        ? [NSSortDescriptor(
            key: #keyPath(Card.name),
            ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )]
        : []
        return try cardRepo.fetchAll(sortDescriptors: sort)
    }
    
    // MARK: fetchCards(forBudgetID:)
    /// Fetch all cards linked to a specific Budget.
    /// - Parameter budgetID: The Budget's UUID.
    /// - Returns: Array of Card used by that budget.
    func fetchCards(forBudgetID budgetID: UUID) throws -> [Card] {
        // Use literal KVC key path to avoid keyPath/Identifiable ambiguity.
        let predicate = NSPredicate(format: "ANY budget.id == %@", budgetID as CVarArg)
        let sort = [NSSortDescriptor(
            key: #keyPath(Card.name),
            ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )]
        return try cardRepo.fetchAll(predicate: predicate, sortDescriptors: sort)
    }
    
    // MARK: findCard(byID:)
    /// Find a single card by UUID.
    /// - Parameter id: Card UUID.
    /// - Returns: Card or nil if not found.
    func findCard(byID id: UUID) throws -> Card? {
        // Literal "id" avoids the same ambiguity issues.
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try cardRepo.fetchFirst(predicate: predicate)
    }
    
    // MARK: countCards(named:)
    /// Count cards with a given exact (case-insensitive) name.
    /// - Parameter name: Target name.
    /// - Returns: Number of cards matching.
    func countCards(named name: String) throws -> Int {
        let predicate = NSPredicate(format: "name =[c] %@", name)
        return try cardRepo.count(predicate: predicate)
    }
    
    // MARK: createCard(name:ensureUniqueName:attachToBudgetIDs:)
    /// Create a new card, optionally ensuring unique name and attaching to budgets.
    /// - Parameters:
    ///   - name: Display name for the card.
    ///   - ensureUniqueName: If true, will return the existing card when a case-insensitive name match exists.
    ///   - attachToBudgetIDs: Optional list of Budget IDs to link this card to.
    /// - Returns: The created (or existing) Card.
    @discardableResult
    func createCard(name: String,
                    ensureUniqueName: Bool = true,
                    attachToBudgetIDs: [UUID] = []) throws -> Card {
        if ensureUniqueName {
            let existing = try cardRepo.fetchFirst(
                predicate: NSPredicate(format: "name =[c] %@", name)
            )
            if let existing { return existing }
        }
        
        let card = cardRepo.create { c in
            // Assign via KVC to avoid `.id` ambiguity when Identifiable is also present.
            c.setValue(UUID(), forKey: "id")
            c.name = name
        }
        
        if !attachToBudgetIDs.isEmpty {
            try attachCard(card, toBudgetsWithIDs: attachToBudgetIDs)
        }
        
        try cardRepo.saveIfNeeded()
        return card
    }
    
    // MARK: renameCard(_:to:)
    /// Rename a card.
    /// - Parameters:
    ///   - card: The managed `Card` instance to rename.
    ///   - newName: New display name.
    func renameCard(_ card: Card, to newName: String) throws {
        card.name = newName
        try cardRepo.saveIfNeeded()
    }
    
    // MARK: updateCard(_:name:)
    /// Update multiple fields of a card. (Currently just name; extend here if you add attributes.)
    /// - Parameters:
    ///   - card: The managed `Card` instance to update.
    ///   - name: Optional new name.
    func updateCard(_ card: Card, name: String? = nil) throws {
        if let name { card.name = name }
        try cardRepo.saveIfNeeded()
    }
    
    // MARK: deleteCard(_:)
    /// Delete a card.
    /// - Important: If your data model does not cascade delete `UnplannedExpense` from `Card`,
    ///   you may need to reassign or explicitly delete related expenses before calling this.
    /// - Parameter card: Card to delete.
    func deleteCard(_ card: Card) throws {
        cardRepo.delete(card)
        try cardRepo.saveIfNeeded()
    }
    
    // MARK: deleteAllCards()
    /// DANGER: Delete all cards. Mostly for tests/resets.
    func deleteAllCards() throws {
        try cardRepo.deleteAll()
    }
    
    // MARK: attachCard(_:toBudgetsWithIDs:)
    /// Attach a card to one or more budgets by UUID.
    /// - Parameters:
    ///   - card: The `Card` to attach.
    ///   - budgetIDs: Array of Budget UUIDs to link.
    func attachCard(_ card: Card, toBudgetsWithIDs budgetIDs: [UUID]) throws {
        guard !budgetIDs.isEmpty else { return }
        
        // Fetch budgets by IDs using literal "id" to avoid ambiguity.
        let predicate = NSPredicate(format: "id IN %@", budgetIDs)
        let budgets = try budgetRepo.fetchAll(predicate: predicate)
        
        // Use a KVC set for codegen-agnostic safety (works whether the relation is NSSet or Set<Budget>).
        let budgetSet = card.mutableSetValue(forKey: "budget")
        budgets.forEach { budgetSet.add($0) }
        
        try cardRepo.saveIfNeeded()
    }
    
    // MARK: detachCard(_:fromBudgetsWithIDs:)
    /// Detach a card from one or more budgets by UUID.
    /// - Parameters:
    ///   - card: The `Card` to detach.
    ///   - budgetIDs: Array of Budget UUIDs to unlink.
    func detachCard(_ card: Card, fromBudgetsWithIDs budgetIDs: [UUID]) throws {
        guard !budgetIDs.isEmpty else { return }
        
        // Fetch budgets by IDs using literal "id" to avoid ambiguity.
        let predicate = NSPredicate(format: "id IN %@", budgetIDs)
        let budgets = try budgetRepo.fetchAll(predicate: predicate)
        
        let budgetSet = card.mutableSetValue(forKey: "budget")
        budgets.forEach { budgetSet.remove($0) }
        
        try cardRepo.saveIfNeeded()
    }
    
    // MARK: replaceCard(_:budgetsWithIDs:)
    /// Replace all budget links for a card with a new set of budgets (by IDs).
    /// - Parameters:
    ///   - card: The `Card` whose links you want to replace.
    ///   - budgetIDs: The complete, final list of Budget IDs that should be linked to this card.
    func replaceCard(_ card: Card, budgetsWithIDs budgetIDs: [UUID]) throws {
        // Desired (fetch by literal "id")
        let desiredPredicate = budgetIDs.isEmpty
        ? NSPredicate(value: false) // nothing desired
        : NSPredicate(format: "id IN %@", budgetIDs)
        let desiredBudgets = try budgetRepo.fetchAll(predicate: desiredPredicate)
        let desiredSet = Set(desiredBudgets.map { $0.objectID })
        
        // Current
        let currentSet = card.mutableSetValue(forKey: "budget")
        let currentBudgets = (currentSet.allObjects as? [Budget]) ?? []
        let currentIDs = Set(currentBudgets.map { $0.objectID })
        
        // Remove ones no longer desired
        currentBudgets
            .filter { !desiredSet.contains($0.objectID) }
            .forEach { currentSet.remove($0) }
        
        // Add ones missing
        desiredBudgets
            .filter { !currentIDs.contains($0.objectID) }
            .forEach { currentSet.add($0) }
        
        try cardRepo.saveIfNeeded()
    }
}
