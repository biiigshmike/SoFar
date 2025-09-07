import Foundation
import CoreData

/// Centralized recurrence expansion used by Income, UnplannedExpense and Budget services.
/// Handles both legacy keyword strings ("weekly", "monthly", etc.) and
/// modern ICS RRULE strings produced by `RecurrenceRule`.
struct RecurrenceEngine {
    /// Generate projected recurrence dates for an event.
    /// - Parameters:
    ///   - recurrence: Either a simple keyword ("weekly", "monthly", etc.) or an ICS RRULE string.
    ///   - baseDate: The first occurrence date stored in persistence.
    ///   - interval: Date range to expand within.
    ///   - calendar: Calendar to use for calculations.
    ///   - secondBiMonthlyDay: Optional second day-of-month for semi-monthly schedules.
    ///   - secondBiMonthlyDate: Optional explicit second date for semi-monthly schedules.
    /// - Returns: Array of dates for additional projected occurrences (including the base date if it falls in the interval).
    static func projectedDates(recurrence: String?,
                               baseDate: Date,
                               in interval: DateInterval,
                               calendar: Calendar = .current,
                               secondBiMonthlyDay: Int16? = nil,
                               secondBiMonthlyDate: Date? = nil) -> [Date] {
        guard let recurrence = recurrence?.lowercased(), !recurrence.isEmpty else { return [] }

        // Determine if the string is an ICS RRULE
        if recurrence.contains("freq=") {
            if let rule = RecurrenceRule.parse(from: recurrence,
                                               endDate: nil,
                                               secondBiMonthlyPayDay: Int(secondBiMonthlyDay ?? 0)) {
                return projectedDates(from: rule,
                                      baseDate: baseDate,
                                      interval: interval,
                                      calendar: calendar,
                                      secondBiMonthlyDay: secondBiMonthlyDay,
                                      secondBiMonthlyDate: secondBiMonthlyDate)
            }
            return []
        } else {
            return projectedDates(fromKeyword: recurrence,
                                  baseDate: baseDate,
                                  interval: interval,
                                  calendar: calendar,
                                  secondBiMonthlyDay: secondBiMonthlyDay,
                                  secondBiMonthlyDate: secondBiMonthlyDate)
        }
    }

    // MARK: - Keyword Handling
    private static func projectedDates(fromKeyword keyword: String,
                                      baseDate: Date,
                                      interval: DateInterval,
                                      calendar: Calendar,
                                      secondBiMonthlyDay: Int16?,
                                      secondBiMonthlyDate: Date?) -> [Date] {
        switch keyword {
        case "daily":
            return strideDates(start: baseDate, stepDays: 1, within: interval, calendar: calendar)
        case "weekly":
            return strideDates(start: baseDate, stepDays: 7, within: interval, calendar: calendar)
        case "biweekly":
            return strideDates(start: baseDate, stepDays: 14, within: interval, calendar: calendar)
        case "monthly":
            return strideMonthly(start: baseDate, stepMonths: 1, within: interval, calendar: calendar)
        case "quarterly":
            return strideMonthly(start: baseDate, stepMonths: 3, within: interval, calendar: calendar)
        case "yearly":
            return strideYearly(start: baseDate, within: interval, calendar: calendar)
        case "semimonthly":
            if let second = secondBiMonthlyDate {
                return strideSemiMonthly(start: baseDate,
                                         within: interval,
                                         calendar: calendar,
                                         secondDate: second)
            }
            return strideSemiMonthly(start: baseDate,
                                     within: interval,
                                     calendar: calendar,
                                     secondDay: secondBiMonthlyDay)
        default:
            return []
        }
    }

    // MARK: - RRULE Handling
    private static func projectedDates(from rule: RecurrenceRule,
                                       baseDate: Date,
                                       interval: DateInterval,
                                       calendar: Calendar,
                                       secondBiMonthlyDay: Int16?,
                                       secondBiMonthlyDate: Date?) -> [Date] {
        switch rule {
        case .daily:
            return strideDates(start: baseDate, stepDays: 1, within: interval, calendar: calendar)
        case .weekly:
            return strideDates(start: baseDate, stepDays: 7, within: interval, calendar: calendar)
        case .biWeekly:
            return strideDates(start: baseDate, stepDays: 14, within: interval, calendar: calendar)
        case .monthly:
            return strideMonthly(start: baseDate, stepMonths: 1, within: interval, calendar: calendar)
        case .quarterly:
            return strideMonthly(start: baseDate, stepMonths: 3, within: interval, calendar: calendar)
        case .annually:
            return strideYearly(start: baseDate, within: interval, calendar: calendar)
        case .semiMonthly(_, let second, _):
            if let secondDate = secondBiMonthlyDate {
                return strideSemiMonthly(start: baseDate,
                                         within: interval,
                                         calendar: calendar,
                                         secondDate: secondDate)
            }
            return strideSemiMonthly(start: baseDate,
                                     within: interval,
                                     calendar: calendar,
                                     secondDay: Int16(second))
        case .custom, .none:
            return []
        }
    }

    // MARK: - Core Stride Helpers
    private static func strideDates(start: Date, stepDays: Int, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = start
        if current < interval.start {
            let delta = calendar.dateComponents([.day], from: start, to: interval.start).day ?? 0
            let steps = (delta + stepDays - 1) / stepDays
            current = calendar.date(byAdding: .day, value: steps * stepDays, to: start) ?? interval.start
        }
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: current) else { break }
            current = next
        }
        return dates
    }

    private static func strideMonthly(start: Date, stepMonths: Int, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = alignedToInterval(start: start, unit: .month, step: stepMonths, within: interval, calendar: calendar)
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .month, value: stepMonths, to: current) else { break }
            current = next
        }
        return dates
    }

    private static func strideYearly(start: Date, within interval: DateInterval, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var current = alignedToInterval(start: start, unit: .year, step: 1, within: interval, calendar: calendar)
        while current <= interval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .year, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    // Semi-monthly using explicit second date
    private static func strideSemiMonthly(start: Date,
                                          within interval: DateInterval,
                                          calendar: Calendar,
                                          secondDate: Date) -> [Date] {
        let secondDay = calendar.component(.day, from: secondDate)
        return strideSemiMonthly(start: start,
                                 within: interval,
                                 calendar: calendar,
                                 secondDay: Int16(secondDay))
    }

    // Semi-monthly using day-of-month
    private static func strideSemiMonthly(start: Date,
                                          within interval: DateInterval,
                                          calendar: Calendar,
                                          secondDay: Int16?) -> [Date] {
        var results: [Date] = []
        let baseDay = calendar.component(.day, from: start)
        let second = Int(secondDay ?? Int16(max(1, min(28, baseDay <= 15 ? 30 : 15))))
        var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: max(start, interval.start))) ?? calendar.startOfDay(for: start)
        while monthStart <= interval.end {
            if let d1 = clampedDayInMonth(baseDay, near: monthStart, calendar: calendar),
               interval.contains(d1), d1 >= start { results.append(d1) }
            if let d2 = clampedDayInMonth(second, near: monthStart, calendar: calendar),
               interval.contains(d2), d2 >= start { results.append(d2) }
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return results.sorted()
    }

    // MARK: - Utilities
    private static func alignedToInterval(start: Date,
                                          unit: Calendar.Component,
                                          step: Int,
                                          within interval: DateInterval,
                                          calendar: Calendar) -> Date {
        var current = start
        while current < interval.start {
            guard let next = calendar.date(byAdding: unit, value: step, to: current) else { break }
            current = next
        }
        return current
    }

    private static func clampedDayInMonth(_ day: Int, near monthAnchor: Date, calendar: Calendar) -> Date? {
        let range = calendar.range(of: .day, in: .month, for: monthAnchor) ?? (1..<29)
        let lastValid = max(range.lowerBound, range.upperBound - 1)
        let clamped = max(range.lowerBound, min(day, lastValid))
        var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        comps.day = clamped
        return calendar.date(from: comps)
    }

    // MARK: - Persistence Helpers (Income)
    /// Regenerates persisted income instances for the recurrence defined on `income`.
    /// Existing child instances (where `parentID == income.id`) are removed before regeneration.
    /// - Parameters:
    ///   - income: The base income that defines the recurrence pattern.
    ///   - context: Managed object context used for fetch/create/delete.
    ///   - calendar: Calendar to use for date calculations.
    static func regenerateIncomeRecurrences(base income: Income,
                                            in context: NSManagedObjectContext,
                                            calendar: Calendar = .current) throws {
        guard let baseID = income.id else { return }

        // Remove existing children for this series
        let request: NSFetchRequest<Income> = Income.fetchRequest()
        request.predicate = NSPredicate(format: "parentID == %@", baseID as CVarArg)
        let existingChildren = try context.fetch(request)
        existingChildren.forEach { context.delete($0) }

        // Only proceed if a recurrence rule exists
        guard let recurrence = income.recurrence, !recurrence.isEmpty,
              let startDate = income.date else { return }

        // Determine expansion window
        let end = income.recurrenceEndDate ?? calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        let interval = DateInterval(start: startDate, end: end)

        let dates = projectedDates(recurrence: recurrence,
                                   baseDate: startDate,
                                   in: interval,
                                   calendar: calendar)

        for d in dates {
            if calendar.isDate(d, inSameDayAs: startDate) { continue }
            let copy = Income(context: context)
            copy.id = UUID()
            copy.source = income.source
            copy.amount = income.amount
            copy.isPlanned = income.isPlanned
            copy.date = d
            copy.parentID = baseID
        }
    }
}

