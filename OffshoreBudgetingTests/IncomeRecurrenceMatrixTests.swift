import Foundation
import Testing
@testable import Offshore

@MainActor
struct IncomeRecurrenceMatrixTests {

    // MARK: - Helpers
    private func utcCalendar() -> Calendar { TestUtils.utcCalendar() }

    private struct Pattern {
        let name: String
        let secondDay: Int16?
    }

    @Test
    func planned_and_actual_all_recurrences_oct2025_to_oct2026() throws {
        _ = try TestUtils.resetStore()
        let cal = utcCalendar()
        let service = IncomeService(calendar: cal)

        let start = TestUtils.makeDate(2025, 10, 1)
        let end = TestUtils.makeDate(2026, 10, 1)
        let window = DateInterval(start: start, end: end)

        // Recurrence patterns to validate (keyword engine)
        let patterns: [Pattern] = [
            .init(name: "daily", secondDay: nil),
            .init(name: "weekly", secondDay: nil),
            .init(name: "biweekly", secondDay: nil),
            .init(name: "monthly", secondDay: nil),
            .init(name: "quarterly", secondDay: nil),
            .init(name: "yearly", secondDay: nil),
            .init(name: "semimonthly", secondDay: 20)
        ]

        // Amounts per type for clean expected totals
        let plannedAmount: Double = 100
        let actualAmount: Double = 75

        var expectedPlannedTotal: Double = 0
        var expectedActualTotal: Double = 0

        for p in patterns {
            // Planned series
            let plannedBase = try service.createIncome(
                source: "planned-\(p.name)",
                amount: plannedAmount,
                date: start,
                isPlanned: true,
                recurrence: p.name,
                recurrenceEndDate: end,
                secondBiMonthlyDay: p.secondDay
            )
            // Persisted series count should match projected series count (including base)
            let incomesP = try service.fetchIncomes(in: window)
            let seriesP = incomesP.filter { $0.parentID == plannedBase.id || $0.id == plannedBase.id }
            let expectedDatesP = RecurrenceEngine.projectedDates(
                recurrence: p.name,
                baseDate: start,
                in: window,
                calendar: cal,
                secondBiMonthlyDay: p.secondDay,
                secondBiMonthlyDate: nil
            )
            #expect(seriesP.count == expectedDatesP.count)
            expectedPlannedTotal += Double(expectedDatesP.count) * plannedAmount

            // Actual series
            let actualBase = try service.createIncome(
                source: "actual-\(p.name)",
                amount: actualAmount,
                date: start,
                isPlanned: false,
                recurrence: p.name,
                recurrenceEndDate: end,
                secondBiMonthlyDay: p.secondDay
            )
            let incomesA = try service.fetchIncomes(in: window)
            let seriesA = incomesA.filter { $0.parentID == actualBase.id || $0.id == actualBase.id }
            let expectedDatesA = RecurrenceEngine.projectedDates(
                recurrence: p.name,
                baseDate: start,
                in: window,
                calendar: cal,
                secondBiMonthlyDay: p.secondDay,
                secondBiMonthlyDate: nil
            )
            #expect(seriesA.count == expectedDatesA.count)
            expectedActualTotal += Double(expectedDatesA.count) * actualAmount
        }

        // Validate totals against IncomeService aggregate helpers
        let plannedTotal = try service.totalAmount(in: window, includePlanned: true)
        let actualTotal  = try service.totalAmount(in: window, includePlanned: false)
        #expect(abs(plannedTotal - expectedPlannedTotal) < 0.0001)
        #expect(abs(actualTotal  - expectedActualTotal)  < 0.0001)
    }
}

