import Foundation
import CoreData

extension RecurrenceEngine {
    /// Scope for editing or deleting a recurrence series.
    enum SeriesScope {
        case instance
        case futureInstances
        case allInstances
    }

    /// Persist additional `Income` objects for the recurrence defined on `base`.
    /// The `base` income must already be inserted and saved so its `id` is valid.
    /// New instances are created in `context` with their `parentID` set to the base `id`.
    ///
    /// - Parameters:
    ///   - base: The already-persisted first occurrence of the series.
    ///   - context: Managed object context used to create additional instances.
    ///   - calendar: Calendar used for date math (defaults to current).
    static func persistIncomeSeries(base: Income,
                                    in context: NSManagedObjectContext,
                                    calendar: Calendar = .current) throws {
        guard let recurrence = base.recurrence, !recurrence.isEmpty else { return }
        let startDate = base.date ?? Date()
        let endDate = base.recurrenceEndDate ?? calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        let interval = DateInterval(start: startDate, end: endDate)
        let secondDay = base.value(forKey: "secondPayDay") as? Int16
        let dates = projectedDates(recurrence: recurrence,
                                   baseDate: startDate,
                                   in: interval,
                                   calendar: calendar,
                                   secondBiMonthlyDay: secondDay)
        for d in dates {
            if calendar.isDate(d, inSameDayAs: startDate) { continue }
            let clone = Income(context: context)
            clone.setValue(UUID(), forKey: "id")
            clone.source = base.source
            clone.amount = base.amount
            clone.date = d
            clone.isPlanned = base.isPlanned
            clone.recurrence = base.recurrence
            clone.recurrenceEndDate = base.recurrenceEndDate
            if let secondDay { clone.setValue(secondDay, forKey: "secondPayDay") }
            clone.setValue(base.value(forKey: "id"), forKey: "parentID")
        }
    }

    /// Delete incomes in the recurrence series based on the provided scope.
    /// - Parameters:
    ///   - income: An income within the series to delete.
    ///   - scope: Whether to delete only this instance, this and future instances, or all instances.
    ///   - context: Managed object context to perform deletions in.
    ///   - calendar: Calendar for date comparisons.
    static func delete(income: Income,
                       scope: SeriesScope,
                       in context: NSManagedObjectContext,
                       calendar: Calendar = .current) throws {
        let seriesID = income.value(forKey: "parentID") as? UUID ?? income.value(forKey: "id") as? UUID
        switch scope {
        case .instance:
            context.delete(income)
        case .futureInstances:
            guard let seriesID else { context.delete(income); return }
            let predicate = NSPredicate(format: "(parentID == %@ OR id == %@) AND date >= %@",
                                        seriesID as CVarArg, seriesID as CVarArg, (income.date ?? Date()) as CVarArg)
            let request = NSFetchRequest<Income>(entityName: "Income")
            request.predicate = predicate
            let results = try context.fetch(request)
            for inc in results { context.delete(inc) }
        case .allInstances:
            guard let seriesID else { context.delete(income); return }
            let predicate = NSPredicate(format: "parentID == %@ OR id == %@",
                                        seriesID as CVarArg, seriesID as CVarArg)
            let request = NSFetchRequest<Income>(entityName: "Income")
            request.predicate = predicate
            let results = try context.fetch(request)
            for inc in results { context.delete(inc) }
        }
    }

    /// Apply modifications to incomes within a series according to the given scope.
    /// - Parameters:
    ///   - income: An income within the series to modify.
    ///   - scope: Range of instances to modify.
    ///   - context: Managed object context for fetching and saving changes.
    ///   - calendar: Calendar for date calculations.
    ///   - modify: Closure applied to each targeted income.
    static func update(income: Income,
                       scope: SeriesScope,
                       in context: NSManagedObjectContext,
                       calendar: Calendar = .current,
                       modify: (Income) -> Void) throws {
        let seriesID = income.value(forKey: "parentID") as? UUID ?? income.value(forKey: "id") as? UUID
        switch scope {
        case .instance:
            modify(income)
        case .futureInstances:
            guard let seriesID else { modify(income); return }
            let predicate = NSPredicate(format: "(parentID == %@ OR id == %@) AND date >= %@",
                                        seriesID as CVarArg, seriesID as CVarArg, (income.date ?? Date()) as CVarArg)
            let request = NSFetchRequest<Income>(entityName: "Income")
            request.predicate = predicate
            let results = try context.fetch(request)
            for inc in results { modify(inc) }
        case .allInstances:
            guard let seriesID else { modify(income); return }
            let predicate = NSPredicate(format: "parentID == %@ OR id == %@",
                                        seriesID as CVarArg, seriesID as CVarArg)
            let request = NSFetchRequest<Income>(entityName: "Income")
            request.predicate = predicate
            let results = try context.fetch(request)
            for inc in results { modify(inc) }
        }
    }
}
