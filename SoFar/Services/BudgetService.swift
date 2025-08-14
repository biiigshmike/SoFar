//
//  BudgetService.swift
//  SoFar
//
//  CRUD for Budget plus a few focused queries.
//  This aligns with the current model (isRecurring, recurrenceType, recurrenceEndDate).
//  NOTE: Current model has Budget.incomes as maxCount=1 (to-one). If you later flip to to-many,
//  method signatures won’t need to change—only the relationship wiring.
//
//  Future: aggregations for planned/unplanned spend likely need either a Budget↔UnplannedExpense link
//  or queries via Card/date ranges. For now we stick to core CRUD + basic fetches.
//

import Foundation
import CoreData

// MARK: - BudgetService
/// Public API for managing `Budget` entities.
final class BudgetService {
    
    // MARK: Properties
    /// Generic repository for Budget entity.
    private let repo = CoreDataRepository<Budget>()
    
    // MARK: fetchAllBudgets(sortByStartDateDescending:)
    /// Return all budgets, sorted by start date (DESC by default, newest first).
    /// - Parameter sortByStartDateDescending: If true (default), newest first.
    /// - Returns: Array of Budget.
    func fetchAllBudgets(sortByStartDateDescending: Bool = true) throws -> [Budget] {
        let sort = NSSortDescriptor(key: #keyPath(Budget.startDate), ascending: !sortByStartDateDescending)
        return try repo.fetchAll(sortDescriptors: [sort])
    }
    
    // MARK: findBudget(byID:)
    /// Fetch a single budget by UUID.
    /// - Parameter id: Budget UUID.
    /// - Returns: Budget or nil.
    func findBudget(byID id: UUID) throws -> Budget? {
        // ✅ Literal "id" avoids ambiguity with Identifiable.
        let predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try repo.fetchFirst(predicate: predicate)
    }
    
    // MARK: fetchActiveBudget(on:)
    /// Find a budget active on a given date (startDate...endDate contains the date).
    /// - Parameter date: Date to test (defaults to now).
    /// - Returns: Budget or nil.
    func fetchActiveBudget(on date: Date = Date()) throws -> Budget? {
        let predicate = NSPredicate(format: "(%K <= %@) AND (%K >= %@)",
                                    #keyPath(Budget.startDate), date as CVarArg,
                                    #keyPath(Budget.endDate), date as CVarArg)
        let sort = NSSortDescriptor(key: #keyPath(Budget.startDate), ascending: false)
        return try repo.fetchFirst(predicate: predicate, sortDescriptors: [sort])
    }
    
    // MARK: createBudget(...)
    /// Create a new budget.
    /// - Parameters:
    ///   - name: Display name.
    ///   - startDate: Start date (inclusive).
    ///   - endDate: End date (inclusive).
    ///   - isRecurring: Whether this template repeats.
    ///   - recurrenceType: Free-form or enumerated string (e.g., "monthly", "biweekly").
    ///   - recurrenceEndDate: End of recurrence schedule, if any.
    ///   - parentID: If this budget is derived from a parent template.
    /// - Returns: The newly created Budget.
    @discardableResult
    func createBudget(name: String,
                      startDate: Date,
                      endDate: Date,
                      isRecurring: Bool = false,
                      recurrenceType: String? = nil,
                      recurrenceEndDate: Date? = nil,
                      parentID: UUID? = nil) throws -> Budget {
        let budget = repo.create { b in
            // ✅ Assign via KVC to avoid `.id` ambiguity.
            b.setValue(UUID(), forKey: "id")
            b.name = name
            b.startDate = startDate
            b.endDate = endDate
            // Model’s generated property is Bool, not NSNumber.
            b.isRecurring = isRecurring
            b.recurrenceType = recurrenceType
            b.recurrenceEndDate = recurrenceEndDate
            // Property is UUID?, so assign UUID? directly.
            b.parentID = parentID
        }
        try repo.saveIfNeeded()
        return budget
    }
    
    // MARK: updateBudget(_:name:dates:isRecurring:recurrenceType:recurrenceEndDate:parentID:)
    /// Update basic budget fields. Pass only the fields you want to change.
    /// - Parameters:
    ///   - budget: The budget to update.
    ///   - name: Optional new name.
    ///   - dates: Optional new (start, end) tuple.
    ///   - isRecurring: Optional new recurring flag.
    ///   - recurrenceType: Optional new recurrence type string.
    ///   - recurrenceEndDate: Optional new recurrence end date.
    ///   - parentID: Optional new parent UUID.
    func updateBudget(_ budget: Budget,
                      name: String? = nil,
                      dates: (start: Date, end: Date)? = nil,
                      isRecurring: Bool? = nil,
                      recurrenceType: String? = nil,
                      recurrenceEndDate: Date? = nil,
                      parentID: UUID? = nil) throws {
        if let name { budget.name = name }
        if let dates {
            budget.startDate = dates.start
            budget.endDate = dates.end
        }
        // Property is Bool, so assign Bool directly.
        if let isRecurring { budget.isRecurring = isRecurring }
        if let recurrenceType { budget.recurrenceType = recurrenceType }
        if let recurrenceEndDate { budget.recurrenceEndDate = recurrenceEndDate }
        // Property is UUID?, so assign UUID? directly.
        if let parentID { budget.parentID = parentID }
        try repo.saveIfNeeded()
    }
    
    // MARK: deleteBudget(_:)
    /// Delete a budget. Consider how to handle attached relationships first (cards, incomes, plannedExpense).
    /// - Parameter budget: Budget to delete.
    func deleteBudget(_ budget: Budget) throws {
        repo.delete(budget)
        try repo.saveIfNeeded()
    }
}
