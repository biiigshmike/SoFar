//
//  AddBudgetViewModel.swift
//  SoFar
//
//  Handles data loading and saving for the Add/Edit Budget screen.
//  - ADD: create a new Budget, attach selected Cards, optionally clone global templates
//  - EDIT: preload an existing Budget and update it in-place (name, dates, cards)
//

import Foundation
import CoreData
import SwiftUI

// MARK: - AddBudgetViewModel
@MainActor
final class AddBudgetViewModel: ObservableObject {

    // MARK: Inputs (bound to UI)
    @Published var budgetName: String
    @Published var startDate: Date
    @Published var endDate: Date

    // MARK: Loaded Data (Core Data)
    @Published private(set) var allCards: [Card] = []
    @Published private(set) var globalPlannedExpenseTemplates: [PlannedExpense] = []

    // MARK: Selections
    /// Using objectIDs avoids relying on optional UUID attributes.
    @Published var selectedCardObjectIDs: Set<NSManagedObjectID> = []
    @Published var selectedTemplateObjectIDs: Set<NSManagedObjectID> = []

    // MARK: Dependencies
    private let context: NSManagedObjectContext

    // MARK: Editing
    /// If non-nil, we're editing an existing Budget and will update it in-place.
    private let editingBudgetObjectID: NSManagedObjectID?
    var isEditing: Bool { editingBudgetObjectID != nil }

    /// Default title based on the suggested dates/period.
    let defaultBudgetName: String

    // MARK: Init
    /// - Parameters:
    ///   - context: Core Data context (defaults to app viewContext)
    ///   - startDate: Initial start date (or preloaded when editing)
    ///   - endDate: Initial end date (or preloaded when editing)
    ///   - editingBudgetObjectID: Provide when editing an existing Budget
    init(
        context: NSManagedObjectContext = CoreDataService.shared.viewContext,
        startDate: Date,
        endDate: Date,
        editingBudgetObjectID: NSManagedObjectID? = nil
    ) {
        self.context = context
        self.startDate = startDate
        self.endDate = endDate
        self.editingBudgetObjectID = editingBudgetObjectID

        // Compute default name based on the provided period.
        self.defaultBudgetName = Self.makeDefaultName(startDate: startDate, endDate: endDate)
        self.budgetName = defaultBudgetName

        // FIX: Synchronous preload so the first frame of the sheet isn't blank.
        // This does not require the async .load(); it gives us non-empty fields immediately.
        if let id = editingBudgetObjectID {
            CoreDataService.shared.ensureLoaded()
            if let existing = try? context.existingObject(with: id) as? Budget {
                budgetName = (existing.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let s = existing.startDate { self.startDate = s }
                if let e = existing.endDate { self.endDate = e }
                if let set = existing.cards as? Set<Card> {
                    selectedCardObjectIDs = Set(set.map { $0.objectID })
                }

                // Preload global templates and current selections so the first frame isn't blank.
                globalPlannedExpenseTemplates = fetchGlobalPlannedExpenseTemplates()
                let existingInstances = fetchPlannedExpenses(for: existing)
                selectedTemplateObjectIDs = Set(globalPlannedExpenseTemplates.compactMap { template in
                    existingInstances.contains(where: { $0.globalTemplateID == template.id })
                        ? template.objectID
                        : nil
                })
            }
        }
    }

    /// Generates a default budget name based on the period implied by the
    /// provided start and end dates.
    private static func makeDefaultName(startDate: Date, endDate: Date) -> String {
        let period = BudgetPeriod.selectableCases.first { $0.matches(startDate: startDate, endDate: endDate) } ?? .custom
        let title = period.title(for: startDate)
        return title.isEmpty ? "\(period.displayName) Budget" : "\(title) Budget"
    }

    // MARK: Validation
    var canSave: Bool {
        !budgetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && startDate <= endDate
    }

    // MARK: load()
    /// Loads cards and global planned-expense templates.
    /// When editing, refreshes the Budget fields and current template selections.
    func load() async {
        CoreDataService.shared.ensureLoaded()
        await CoreDataService.shared.waitUntilStoresLoaded()

        allCards = fetchCards()
        globalPlannedExpenseTemplates = fetchGlobalPlannedExpenseTemplates()

        if isEditing, let id = editingBudgetObjectID {
            // Async refresh in case data changed after the sync preload
            if let existing = try? context.existingObject(with: id) as? Budget {
                budgetName = (existing.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let s = existing.startDate { startDate = s }
                if let e = existing.endDate { endDate = e }
                if let set = existing.cards as? Set<Card> {
                    selectedCardObjectIDs = Set(set.map { $0.objectID })
                }
                let existingInstances = fetchPlannedExpenses(for: existing)
                selectedTemplateObjectIDs = Set(globalPlannedExpenseTemplates.compactMap { template in
                    existingInstances.contains(where: { $0.globalTemplateID == template.id })
                        ? template.objectID
                        : nil
                })
            }
        }
    }

    // MARK: save()
    /// If editing, updates the existing Budget.
    /// If adding, creates a new Budget and clones selected global templates.
    func save() throws {
        if isEditing, let id = editingBudgetObjectID {
            try updateExistingBudget(with: id)
        } else {
            try createNewBudget()
        }
    }

    // MARK: - Private (ADD)
    private func createNewBudget() throws {
        let newBudget = Budget(context: context)
        newBudget.id = newBudget.id ?? UUID()
        newBudget.name = budgetName.trimmingCharacters(in: .whitespacesAndNewlines)
        newBudget.startDate = startDate
        newBudget.endDate = endDate

        // Attach selected Cards
        let cardsToAttach = allCards.filter { selectedCardObjectIDs.contains($0.objectID) }
        if !cardsToAttach.isEmpty {
            newBudget.addToCards(NSSet(array: cardsToAttach))
        }

        // Clone selected PlannedExpense templates (global)
        let templates = globalPlannedExpenseTemplates.filter { selectedTemplateObjectIDs.contains($0.objectID) }
        for template in templates {
            let cloned = PlannedExpense(context: context)
            cloned.id = cloned.id ?? UUID()
            cloned.descriptionText = template.descriptionText
            cloned.plannedAmount = template.plannedAmount
            cloned.actualAmount = template.actualAmount
            cloned.transactionDate = startDate
            cloned.isGlobal = false
            cloned.globalTemplateID = template.id
            cloned.budget = newBudget
            cloned.card = template.card
        }

        try context.save()
    }

    // MARK: - Private (EDIT)
    private func updateExistingBudget(with objectID: NSManagedObjectID) throws {
        guard let budget = try context.existingObject(with: objectID) as? Budget else {
            throw NSError(domain: "SoFar.EditBudget", code: 1, userInfo: [NSLocalizedDescriptionKey: "Budget not found."])
        }

        budget.name = budgetName.trimmingCharacters(in: .whitespacesAndNewlines)
        budget.startDate = startDate
        budget.endDate = endDate

        // Replace attached Cards with current selection
        let toAttach = allCards.filter { selectedCardObjectIDs.contains($0.objectID) }
        if let current = budget.cards as? Set<Card>, !current.isEmpty {
            budget.removeFromCards(NSSet(array: Array(current)))
        }
        if !toAttach.isEmpty {
            budget.addToCards(NSSet(array: toAttach))
        }
        // Handle preset planned expense templates
        let existingInstances = fetchPlannedExpenses(for: budget)

        // Add instances for newly selected templates
        let templatesToEnsure = globalPlannedExpenseTemplates.filter { selectedTemplateObjectIDs.contains($0.objectID) }
        for template in templatesToEnsure {
            let tid = template.id
            let already = existingInstances.contains { $0.globalTemplateID == tid }
            if !already {
                let cloned = PlannedExpense(context: context)
                cloned.id = cloned.id ?? UUID()
                cloned.descriptionText = template.descriptionText
                cloned.plannedAmount = template.plannedAmount
                cloned.actualAmount = template.actualAmount
                cloned.transactionDate = startDate
                cloned.isGlobal = false
                cloned.globalTemplateID = tid
                cloned.budget = budget
                cloned.card = template.card
            }
        }

        // Remove instances for templates that are no longer selected
        for instance in existingInstances {
            if let templateID = instance.globalTemplateID,
               let template = globalPlannedExpenseTemplates.first(where: { $0.id == templateID }),
               !selectedTemplateObjectIDs.contains(template.objectID) {
                context.delete(instance)
            }
        }

        try context.save()
    }

    // MARK: Private fetch helpers
    private func fetchCards() -> [Card] {
        let req = NSFetchRequest<Card>(entityName: "Card")
        req.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    private func fetchGlobalPlannedExpenseTemplates() -> [PlannedExpense] {
        let req = NSFetchRequest<PlannedExpense>(entityName: "PlannedExpense")
        req.predicate = NSPredicate(format: "isGlobal == YES")
        req.sortDescriptors = [
            NSSortDescriptor(key: "descriptionText", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        return (try? context.fetch(req)) ?? []
    }

    private func fetchPlannedExpenses(for budget: Budget) -> [PlannedExpense] {
        let req = NSFetchRequest<PlannedExpense>(entityName: "PlannedExpense")
        req.predicate = NSPredicate(format: "budget == %@", budget)
        return (try? context.fetch(req)) ?? []
    }
}
