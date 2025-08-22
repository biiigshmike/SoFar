import Foundation

/// Represents the time span used for grouping budgets.
enum BudgetPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case biWeekly
    case monthly
    case quarterly
    case yearly
    case custom

    var id: String { rawValue }

    /// User-visible name for the period.
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biWeekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }

    /// Periods that can be selected in the UI.
    static var selectableCases: [BudgetPeriod] {
        [.daily, .weekly, .biWeekly, .monthly, .quarterly, .yearly]
    }

    /// Returns the inclusive start date of the period containing `date`.
    func start(of date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.startOfDay(for: date)
        case .weekly:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return cal.date(from: comps) ?? date
        case .biWeekly:
            return BudgetPeriod.weekly.start(of: date)
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: date)
            return cal.date(from: comps) ?? date
        case .quarterly:
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let startMonth = ((month - 1) / 3) * 3 + 1
            return cal.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? date
        case .yearly:
            let comps = cal.dateComponents([.year], from: date)
            return cal.date(from: comps) ?? date
        case .custom:
            return date
        }
    }

    /// Returns the inclusive start and end dates for the period containing `date`.
    func range(containing date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let startDate = start(of: date)
        let endDate: Date
        switch self {
        case .daily:
            endDate = cal.date(byAdding: .day, value: 1, to: startDate)?.addingTimeInterval(-1) ?? startDate
        case .weekly:
            endDate = cal.date(byAdding: .day, value: 7, to: startDate)?.addingTimeInterval(-1) ?? startDate
        case .biWeekly:
            endDate = cal.date(byAdding: .day, value: 14, to: startDate)?.addingTimeInterval(-1) ?? startDate
        case .monthly:
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? startDate
            endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        case .quarterly:
            let end = cal.date(byAdding: DateComponents(month: 3, day: -1), to: startDate) ?? startDate
            endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        case .yearly:
            let end = cal.date(byAdding: DateComponents(year: 1, day: -1), to: startDate) ?? startDate
            endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        case .custom:
            endDate = date
        }
        return (startDate, endDate)
    }

    /// Advances `date` by a number of periods.
    func advance(_ date: Date, by delta: Int) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.date(byAdding: .day, value: delta, to: date) ?? date
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: delta, to: date) ?? date
        case .biWeekly:
            return cal.date(byAdding: .day, value: 14 * delta, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: delta, to: date) ?? date
        case .quarterly:
            return cal.date(byAdding: .month, value: 3 * delta, to: date) ?? date
        case .yearly:
            return cal.date(byAdding: .year, value: delta, to: date) ?? date
        case .custom:
            return date
        }
    }

    /// Human-readable title for the period containing `date`.
    func title(for date: Date) -> String {
        let f = DateFormatter()
        switch self {
        case .daily:
            f.dateFormat = "MMM d, yyyy"
            return f.string(from: start(of: date))
        case .weekly, .biWeekly:
            let range = range(containing: date)
            f.dateFormat = "MMM d"
            let startStr = f.string(from: range.start)
            f.dateFormat = "MMM d, yyyy"
            let endStr = f.string(from: range.end)
            return "\(startStr) - \(endStr)"
        case .monthly:
            f.dateFormat = "LLLL yyyy"
            return f.string(from: date)
        case .quarterly:
            let cal = Calendar.current
            let quarter = (cal.component(.month, from: date) - 1) / 3 + 1
            let year = cal.component(.year, from: date)
            return "Q\(quarter) \(year)"
        case .yearly:
            f.dateFormat = "yyyy"
            return f.string(from: date)
        case .custom:
            return ""
        }
    }
}

