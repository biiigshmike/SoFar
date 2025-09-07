//
//  RecurrenceRule.swift
//  SoFar
//
//  Created by Michael Brown on 8/13/25.
//

import Foundation

// MARK: - Weekday
/// ISO weekday + ICS BYDAY code mapping for simple weekly patterns.
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var icsCode: String {
        switch self {
        case .monday: return "MO"
        case .tuesday: return "TU"
        case .wednesday: return "WE"
        case .thursday: return "TH"
        case .friday: return "FR"
        case .saturday: return "SA"
        case .sunday: return "SU"
        }
    }

    static func fromICS(_ code: String) -> Weekday? {
        switch code.uppercased() {
        case "MO": return .monday
        case "TU": return .tuesday
        case "WE": return .wednesday
        case "TH": return .thursday
        case "FR": return .friday
        case "SA": return .saturday
        case "SU": return .sunday
        default: return nil
        }
    }
}

// MARK: - RecurrenceRule
/// A high-level recurrence selection that can be turned into an ICS RRULE.
/// Supports "none", common presets, and "custom" raw rule.
enum RecurrenceRule: Equatable {
    case none
    case daily(endDate: Date?)
    case weekly(weekday: Weekday, endDate: Date?)
    case biWeekly(weekday: Weekday, endDate: Date?)
    /// Semi-monthly: two calendar days per month, e.g., 1 and 15.
    case semiMonthly(firstDay: Int, secondDay: Int, endDate: Date?)
    case monthly(endDate: Date?)
    case quarterly(endDate: Date?)
    case annually(endDate: Date?)
    case custom(_ rruleString: String, endDate: Date?)

    // MARK: Builder Output
    struct Built {
        let string: String
        let until: Date?
        let secondBiMonthlyPayDay: Int
    }

    // MARK: RRULE Generation
    /// Converts the selection to an ICS RRULE string (or nil for `.none`).
    /// - Parameter starting: First occurrence date; used for some weekly defaults if needed.
    func toRRule(starting: Date) -> Built? {
        switch self {
        case .none:
            return nil
        case .daily(let endDate):
            return Built(string: "FREQ=DAILY", until: endDate, secondBiMonthlyPayDay: 0)
        case .weekly(let weekday, let endDate):
            return Built(string: "FREQ=WEEKLY;BYDAY=\(weekday.icsCode)", until: endDate, secondBiMonthlyPayDay: 0)
        case .biWeekly(let weekday, let endDate):
            return Built(string: "FREQ=WEEKLY;INTERVAL=2;BYDAY=\(weekday.icsCode)", until: endDate, secondBiMonthlyPayDay: 0)
        case .semiMonthly(let d1, let d2, let endDate):
            // Represent as a monthly rule with two BYMONTHDAY entries.
            let bymd = "BYMONTHDAY=\(clampDay(d1)),\(clampDay(d2))"
            return Built(string: "FREQ=MONTHLY;\(bymd)", until: endDate, secondBiMonthlyPayDay: clampDay(d2))
        case .monthly(let endDate):
            return Built(string: "FREQ=MONTHLY", until: endDate, secondBiMonthlyPayDay: 0)
        case .quarterly(let endDate):
            return Built(string: "FREQ=MONTHLY;INTERVAL=3", until: endDate, secondBiMonthlyPayDay: 0)
        case .annually(let endDate):
            return Built(string: "FREQ=YEARLY", until: endDate, secondBiMonthlyPayDay: 0)
        case .custom(let raw, let endDate):
            // Pass-through; assume valid RRULE payload.
            return Built(string: raw, until: endDate, secondBiMonthlyPayDay: 0)
        }
    }

    // MARK: Parse (best-effort)
    /// Parses a stored RRULE string back into a high-level `RecurrenceRule` when possible.
    /// Unknown patterns map to `.custom`.
    static func parse(from rrule: String, endDate: Date?, secondBiMonthlyPayDay: Int) -> RecurrenceRule? {
        let parts = rrule.uppercased().split(separator: ";").map(String.init)

        func part(_ key: String) -> String? {
            parts.first { $0.hasPrefix("\(key)=") }?.split(separator: "=").dropFirst().joined(separator: "=")
        }

        guard let freq = part("FREQ") else {
            // Unknown → treat as custom
            return .custom(rrule, endDate: endDate)
        }

        switch freq {
        case "DAILY":
            return .daily(endDate: endDate)
        case "WEEKLY":
            let interval = Int(part("INTERVAL") ?? "1") ?? 1
            if let bydayStr = part("BYDAY"),
               let wd = Weekday.fromICS(bydayStr) {
                return interval == 2 ? .biWeekly(weekday: wd, endDate: endDate)
                                     : .weekly(weekday: wd, endDate: endDate)
            } else {
                // Default to weekly on start date’s weekday if unspecified
                let calendar = Calendar.current
                let weekdayNum = calendar.component(.weekday, from: Date())
                let wd = Weekday(rawValue: weekdayNum) ?? .monday
                return interval == 2 ? .biWeekly(weekday: wd, endDate: endDate)
                                     : .weekly(weekday: wd, endDate: endDate)
            }
        case "MONTHLY":
            let interval = Int(part("INTERVAL") ?? "1") ?? 1
            if interval == 3 { return .quarterly(endDate: endDate) }
            if let bymd = part("BYMONTHDAY") {
                let days = bymd.split(separator: ",").compactMap { Int($0) }
                if days.count == 2 {
                    return .semiMonthly(firstDay: days[0], secondDay: days[1], endDate: endDate)
                }
            }
            return .monthly(endDate: endDate)
        case "YEARLY":
            return .annually(endDate: endDate)
        default:
            return .custom(rrule, endDate: endDate)
        }
    }

    // MARK: Utilities
    private static func clampDay(_ day: Int) -> Int {
        return min(max(day, 1), 31)
    }
    private func clampDay(_ day: Int) -> Int {
        Self.clampDay(day)
    }
}
