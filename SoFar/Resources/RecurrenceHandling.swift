import Foundation

// MARK: - RecurrenceHandling
/// Shared protocol for view models that expose recurrence configuration.
/// Conforming types provide storage for a selected `RecurrenceRule` and a
/// seed for custom recurrence editing.  A default helper for applying a
/// `CustomRecurrence` is supplied so any conforming view model can easily
/// adopt the custom editor.
protocol RecurrenceHandling: AnyObject {
    var recurrenceRule: RecurrenceRule { get set }
    var customRuleSeed: CustomRecurrence { get set }
}

extension RecurrenceHandling {
    /// Applies a custom recurrence selection, preserving any existing end date.
    func applyCustomRecurrence(_ custom: CustomRecurrence) {
        recurrenceRule = .custom(custom.toRRULE(), endDate: recurrenceRule.endDate)
        customRuleSeed = custom
    }
}

// MARK: - RecurrenceRule helper
private extension RecurrenceRule {
    /// Returns the end date associated with the rule, if any.
    var endDate: Date? {
        switch self {
        case .none:
            return nil
        case .daily(let d), .weekly(_, let d), .biWeekly(_, let d),
             .semiMonthly(_, _, let d), .monthly(let d), .quarterly(let d),
             .annually(let d), .custom(_, let d):
            return d
        }
    }
}

