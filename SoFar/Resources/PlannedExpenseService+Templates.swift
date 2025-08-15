//
//  PlannedExpenseService+Templates.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import Foundation
import CoreData

// MARK: - PlannedExpenseService + Templates
/// Template (global planned expense) helpers used by PresetsView.
/// This extends your existing service (no extra class here).
extension PlannedExpenseService {

    // MARK: Fetch Global Templates
    /// Returns all PlannedExpense where isGlobal == true.
    /// - Parameter context: NSManagedObjectContext
    /// - Returns: [PlannedExpense]
    func fetchGlobalTemplates(in context: NSManagedObjectContext) -> [PlannedExpense] {
        let request: NSFetchRequest<PlannedExpense> = PlannedExpense.fetchRequest()
        request.predicate = NSPredicate(format: "isGlobal == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PlannedExpense.descriptionText, ascending: true)
        ]
        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("fetchGlobalTemplates error: \(error)")
            #endif
            return []
        }
    }

    // MARK: Fetch Children
    /// Fetches non-global PlannedExpense children that reference a template via globalTemplateID.
    /// - Parameters:
    ///   - template: The global PlannedExpense template.
    ///   - context: NSManagedObjectContext
    func fetchChildren(of template: PlannedExpense, in context: NSManagedObjectContext) -> [PlannedExpense] {
        guard let templateID = template.id else { return [] }
        let request: NSFetchRequest<PlannedExpense> = PlannedExpense.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isGlobal == NO"),
            NSPredicate(format: "globalTemplateID == %@", templateID as CVarArg)
        ])
        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("fetchChildren error: \(error)")
            #endif
            return []
        }
    }

    // MARK: Ensure Child (Assign)
    /// Ensures a child PlannedExpense exists for the given budget, copying fields from the template.
    /// - Parameters:
    ///   - template: Global template.
    ///   - budget: Target budget.
    ///   - context: NSManagedObjectContext.
    /// - Returns: The child record (new or existing).
    @discardableResult
    func ensureChild(from template: PlannedExpense,
                     attachedTo budget: Budget,
                     in context: NSManagedObjectContext) -> PlannedExpense {
        if let existing = child(of: template, for: budget, in: context) {
            return existing
        }

        let child = PlannedExpense(context: context)
        child.id = UUID()
        child.descriptionText = template.descriptionText
        child.plannedAmount = template.plannedAmount
        child.actualAmount = 0
        // Use the template's transactionDate as a default due date if present; otherwise, align to budget start.
        child.transactionDate = template.transactionDate ?? budget.startDate ?? Date()
        child.isGlobal = false
        child.globalTemplateID = template.id
        child.budget = budget

        return child
    }

    // MARK: Remove Child (Unassign)
    /// Removes a child PlannedExpense created from the template for a specific budget.
    func removeChild(from template: PlannedExpense,
                     for budget: Budget,
                     in context: NSManagedObjectContext) {
        guard let target = child(of: template, for: budget, in: context) else { return }
        context.delete(target)
    }

    // MARK: Child Lookup
    /// Returns the child PlannedExpense for a specific budget if it exists.
    func child(of template: PlannedExpense,
               for budget: Budget,
               in context: NSManagedObjectContext) -> PlannedExpense? {
        guard let templateID = template.id else { return nil }
        let request: NSFetchRequest<PlannedExpense> = PlannedExpense.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isGlobal == NO"),
            NSPredicate(format: "budget == %@", budget),
            NSPredicate(format: "globalTemplateID == %@", templateID as CVarArg)
        ])
        do {
            return try context.fetch(request).first
        } catch {
            #if DEBUG
            print("child(of:for:) error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: Fetch Budgets (helper)
    /// Returns all budgets sorted by start date descending.
    func fetchAllBudgets(in context: NSManagedObjectContext) -> [Budget] {
        let request: NSFetchRequest<Budget> = Budget.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)
        ]
        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("fetchAllBudgets error: \(error)")
            #endif
            return []
        }
    }

    // MARK: Delete Template + Children
    /// Deletes a global template and any children linked to it.
    func deleteTemplateAndChildren(template: PlannedExpense, in context: NSManagedObjectContext) {
        let kids = fetchChildren(of: template, in: context)
        for k in kids {
            context.delete(k)
        }
        context.delete(template)
    }
}
