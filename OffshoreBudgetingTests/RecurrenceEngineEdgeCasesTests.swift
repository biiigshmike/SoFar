import Foundation
import Testing
@testable import Offshore

struct RecurrenceEngineEdgeCasesTests {

    // MARK: - Helpers
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date.distantPast
    }

    // MARK: - Monthly
    @Test
    func monthly_generates_through_end_inclusive() {
        let cal = utcCalendar()
        let start = makeDate(2025, 9, 1)     // Sep 1, 2025 @ 12:00 UTC
        let end = makeDate(2025, 11, 1)      // Nov 1, 2025 @ 12:00 UTC
        let interval = DateInterval(start: start, end: end)

        // Using ICS RRULE (as produced by UI)
        let datesICS = RecurrenceEngine.projectedDates(
            recurrence: "FREQ=MONTHLY",
            baseDate: start,
            in: interval,
            calendar: cal
        )
        // Using legacy keyword
        let datesKeyword = RecurrenceEngine.projectedDates(
            recurrence: "monthly",
            baseDate: start,
            in: interval,
            calendar: cal
        )

        let expected = [
            makeDate(2025, 9, 1),
            makeDate(2025, 10, 1),
            makeDate(2025, 11, 1)
        ]

        #expect(datesICS == expected)
        #expect(datesKeyword == expected)
    }

    // MARK: - Quarterly
    @Test
    func quarterly_generates_through_end_inclusive() {
        let cal = utcCalendar()
        let start = makeDate(2025, 9, 1)
        let end = makeDate(2026, 10, 1)
        let interval = DateInterval(start: start, end: end)

        let dates = RecurrenceEngine.projectedDates(
            recurrence: "FREQ=MONTHLY;INTERVAL=3",
            baseDate: start,
            in: interval,
            calendar: cal
        )

        let expected = [
            makeDate(2025, 9, 1),
            makeDate(2025, 12, 1),
            makeDate(2026, 3, 1),
            makeDate(2026, 6, 1),
            makeDate(2026, 9, 1)
        ]
        #expect(dates == expected)
    }

    // MARK: - Yearly
    @Test
    func yearly_generates_through_end_inclusive() {
        let cal = utcCalendar()
        let start = makeDate(2025, 9, 1)
        let end = makeDate(2026, 10, 1)
        let interval = DateInterval(start: start, end: end)

        let dates = RecurrenceEngine.projectedDates(
            recurrence: "FREQ=YEARLY",
            baseDate: start,
            in: interval,
            calendar: cal
        )

        let expected = [
            makeDate(2025, 9, 1),
            makeDate(2026, 9, 1)
        ]
        #expect(dates == expected)
    }

    // MARK: - Daily end-date inclusion (regression)
    @Test
    func daily_includes_last_day_when_base_midnight() {
        let cal = utcCalendar()
        let start = makeDate(2025, 9, 1, 0)
        let end = makeDate(2025, 9, 30, 0)
        let interval = DateInterval(start: start, end: end)

        let dates = RecurrenceEngine.projectedDates(
            recurrence: "FREQ=DAILY",
            baseDate: start,
            in: interval,
            calendar: cal
        )

        // Expect 30 dates (Sep 1..30 inclusive)
        #expect(dates.first == start)
        #expect(dates.last == end)
        #expect(dates.count == 30)
    }

    @Test
    func daily_includes_last_day_even_if_end_is_startOfDay() {
        // This simulates a common UI case:
        // - user picks a start date with a daytime time (e.g., 10:00)
        // - user picks an end date via DatePicker(.date) which is midnight start-of-day
        // We expect the series to include the last calendar day the user selected.
        let cal = utcCalendar()
        let start = makeDate(2025, 9, 1, 10)
        let end = makeDate(2025, 9, 30, 0) // midnight start of Sep 30
        let interval = DateInterval(start: start, end: end)

        let dates = RecurrenceEngine.projectedDates(
            recurrence: "FREQ=DAILY",
            baseDate: start,
            in: interval,
            calendar: cal
        )

        // Desired behavior: include Sep 30 (calendar day), not stop at 29th.
        // Current engine compares full Date (time-of-day), so this may fail
        // and stop on the 29th at 10:00, which flags the bug.
        let lastExpected = makeDate(2025, 9, 30, 10)
        #expect(dates.last == lastExpected)
        #expect(dates.count == 30)
    }
}

