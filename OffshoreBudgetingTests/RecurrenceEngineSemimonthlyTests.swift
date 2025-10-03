import Foundation
import Testing
@testable import Offshore

struct RecurrenceEngineSemimonthlyTests {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = h; c.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }

    @Test
    func semimonthly_uses_base_and_second_day_in_month() {
        let cal = utcCalendar()
        let base = makeDate(2025, 9, 5)
        let interval = DateInterval(start: makeDate(2025, 9, 1), end: makeDate(2025, 9, 30))

        // Using keyword + explicit second day-of-month
        let dates = RecurrenceEngine.projectedDates(recurrence: "semimonthly",
                                                    baseDate: base,
                                                    in: interval,
                                                    calendar: cal,
                                                    secondBiMonthlyDay: 20,
                                                    secondBiMonthlyDate: nil)
        let containsBase = dates.contains { cal.isDate($0, inSameDayAs: base) }
        let containsSecond = dates.contains { cal.isDate($0, inSameDayAs: makeDate(2025, 9, 20)) }
        #expect(containsBase)
        #expect(containsSecond)
    }
}
