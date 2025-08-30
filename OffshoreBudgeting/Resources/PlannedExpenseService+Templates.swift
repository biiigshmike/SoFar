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
        child.actualAmount = template.actualAmount
        // Use the template's transactionDate as a default due date if present; otherwise, align to budget start.
        child.transactionDate = template.transactionDate ?? budget.startDate ?? Date()
        child.isGlobal = false
        child.globalTemplateID = template.id
        child.budget = budget
        child.card = template.card

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
    func deleteTemplateAndChildren(template: PlannedExpense, in context: NSManagedObjectContext) throws {
        let kids = fetchChildren(of: template, in: context)
        for k in kids {
            context.delete(k)
        }
        context.delete(template)

        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: Update Template + Propagate
    /// Updates a global template and optionally propagates the same changes to
    /// all existing children starting from a specific date.
    /// - Parameters:
    ///   - template: The global template to update.
    ///   - title: Optional new description/title.
    ///   - plannedAmount: Optional new planned amount.
    ///   - actualAmount: Optional new actual amount.
    ///   - transactionDate: Optional new transaction date.
    ///   - startDate: If provided, child instances with a `transactionDate`
    ///                on/after this date will receive the same updates. Pass
    ///                `nil` to leave existing children untouched.
    ///   - context: NSManagedObjectContext used for fetches.
    func updateTemplate(_ template: PlannedExpense,
                        title: String? = nil,
                        plannedAmount: Double? = nil,
                        actualAmount: Double? = nil,
                        transactionDate: Date? = nil,
                        propagateToChildrenFrom startDate: Date? = nil,
                        in context: NSManagedObjectContext) {
        // Update the template itself
        if let title { template.descriptionText = title }
        if let plannedAmount { template.plannedAmount = plannedAmount }
        if let actualAmount { template.actualAmount = actualAmount }
        if let transactionDate { template.transactionDate = transactionDate }

        // Optionally propagate to children
        guard let startDate else { return }
        let children = fetchChildren(of: template, in: context)
        for child in children {
            if let childDate = child.transactionDate, childDate < startDate { continue }
            if let title { child.descriptionText = title }
            if let plannedAmount { child.plannedAmount = plannedAmount }
            if let actualAmount { child.actualAmount = actualAmount }
            if let transactionDate { child.transactionDate = transactionDate }
        }
    }

    // MARK: Update Child + Optionally Parent/Future Siblings
    /// Updates a child PlannedExpense. When `applyToFutureInstances` is true
    /// the parent template (if any) is updated and the same changes are applied
    /// to all sibling instances with a `transactionDate` on/after the current
    /// child's date.
    func updateChild(_ child: PlannedExpense,
                     title: String? = nil,
                     plannedAmount: Double? = nil,
                     actualAmount: Double? = nil,
                     transactionDate: Date? = nil,
                     applyToFutureInstances: Bool = false,
                     in context: NSManagedObjectContext) {
        // Update the child itself
        if let title { child.descriptionText = title }
        if let plannedAmount { child.plannedAmount = plannedAmount }
        if let actualAmount { child.actualAmount = actualAmount }
        if let transactionDate { child.transactionDate = transactionDate }

        guard applyToFutureInstances, let templateID = child.globalTemplateID else { return }

        // Fetch the parent template
        let req: NSFetchRequest<PlannedExpense> = PlannedExpense.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "id == %@", templateID as CVarArg),
            NSPredicate(format: "isGlobal == YES")
        ])
        req.fetchLimit = 1
        guard let parent = try? context.fetch(req).first else { return }

        // Update parent with the same fields
        if let title { parent.descriptionText = title }
        if let plannedAmount { parent.plannedAmount = plannedAmount }
        if let actualAmount { parent.actualAmount = actualAmount }
        if let transactionDate { parent.transactionDate = transactionDate }

        // Propagate to other future siblings
        let siblings = fetchChildren(of: parent, in: context)
        for sib in siblings {
            // Skip the child we already updated
            if sib == child { continue }
            if let childDate = child.transactionDate,
               let sibDate = sib.transactionDate,
               sibDate < childDate {
                continue
            }
            if let title { sib.descriptionText = title }
            if let plannedAmount { sib.plannedAmount = plannedAmount }
            if let actualAmount { sib.actualAmount = actualAmount }
            if let transactionDate { sib.transactionDate = transactionDate }
        }
    }
}
