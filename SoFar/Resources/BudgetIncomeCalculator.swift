//
//  BudgetIncomeCalculator.swift
//  SoFar
//
//  Created by Michael Brown on 8/13/25.
//

import Foundation
import CoreData

// MARK: - BudgetIncomeCalculator
/// Computes income totals for a given date interval by querying Income globally.
/// No Budget↔Income relationship required.
struct BudgetIncomeCalculator {

    // MARK: Fetch
    /// Returns all incomes intersecting the given date range.
    /// - Parameters:
    ///   - range: DateInterval for the budget window.
    ///   - isPlanned: Optional filter; pass true for planned only, false for actual only, nil for both.
    static func fetchIncomes(in range: DateInterval,
                             isPlanned: Bool? = nil,
                             context: NSManagedObjectContext) throws -> [Income] {
        let request = Income.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "date >= %@ AND date <= %@", range.start as NSDate, range.end as NSDate)
        ]
        if let planned = isPlanned {
            predicates.append(NSPredicate(format: "isPlanned == %@", NSNumber(value: planned)))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.returnsObjectsAsFaults = false
        return try context.fetch(request)
    }

    // MARK: Sum
    /// Sums amounts within a date interval for planned or actual incomes.
    static func sum(in range: DateInterval,
                    isPlanned: Bool? = nil,
                    context: NSManagedObjectContext) throws -> Double {
        let incomes = try fetchIncomes(in: range, isPlanned: isPlanned, context: context)
        return incomes.reduce(0) { $0 + $1.amount }
    }

    // MARK: Totals Bucket
    /// Convenience that returns both planned and actual totals for a budget window.
    static func totals(for range: DateInterval,
                       context: NSManagedObjectContext) throws -> (planned: Double, actual: Double) {
        let planned = try sum(in: range, isPlanned: true, context: context)
        let actual  = try sum(in: range, isPlanned: false, context: context)
        return (planned, actual)
    }
}
