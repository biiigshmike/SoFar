import Foundation
import Testing
@testable import Offshore

@MainActor
struct IncomeAndTotalsTests {

    private func freshIncomeService(calendar: Calendar = TestUtils.utcCalendar()) throws -> IncomeService {
        _ = try TestUtils.resetStore()
        return IncomeService(calendar: calendar)
    }

    @Test
    func income_crud_recurrence_and_grouping() throws {
        let cal = TestUtils.utcCalendar()
        let service = try freshIncomeService(calendar: cal)

        let start = TestUtils.makeDate(2025, 9, 1)
        let end = TestUtils.makeDate(2025, 9, 30)
        let window = DateInterval(start: start, end: end)

        // Create planned weekly paycheck across the month
        let base = TestUtils.makeDate(2025, 9, 5) // first Friday
        let planned = try service.createIncome(source: "Paycheck",
                                               amount: 1000,
                                               date: base,
                                               isPlanned: true,
                                               recurrence: "weekly",
                                               recurrenceEndDate: end)
        #expect(planned.isPlanned == true)

        // Create an actual one-off payment
        let bonus = try service.createIncome(source: "Bonus",
                                             amount: 250,
                                             date: TestUtils.makeDate(2025, 9, 15),
                                             isPlanned: false)
        #expect(bonus.isPlanned == false)

        // Fetch and grouping
        let all = try service.fetchAllIncomes()
        #expect(all.count >= 2)

        let windowIncomes = try service.fetchIncomes(in: window)
        #expect(windowIncomes.count >= 2)

        let dayIncomes = try service.fetchIncomes(on: TestUtils.makeDate(2025, 9, 15))
        #expect(dayIncomes.contains { $0.source == "Bonus" })

        // Find by ID
        let found = try service.findIncome(byID: planned.id!)
        #expect(found?.objectID == planned.objectID)

        // Events and grouping
        let events = try service.events(in: window)
        #expect(events.contains { cal.isDate($0.date, inSameDayAs: base) })

        let grouped = try service.eventsByDay(in: window)
        #expect(!grouped.isEmpty)

        // Totals
        let plannedTotal = try service.totalAmount(in: window, includePlanned: true)
        #expect(plannedTotal >= 4000) // at least 4 Fridays in Sep
        let actualTotal = try service.totalAmount(in: window, includePlanned: false)
        #expect(abs(actualTotal - 250) < 0.0001)

        // Update all occurrences: change amount
        try service.updateIncome(planned, scope: .all, amount: 1100)
        let plannedTotalAfter = try service.totalAmount(in: window, includePlanned: true)
        #expect(plannedTotalAfter >= 4400)

        // Delete future from mid-month
        let mid = TestUtils.makeDate(2025, 9, 18)
        // find the instance on/after mid
        if let inst = try service.fetchIncomes(in: DateInterval(start: mid, end: end)).first(where: { $0.parentID != nil || $0.id == planned.id }) {
            try service.deleteIncome(inst, scope: .future)
            let plannedTotalAfterFutureDelete = try service.totalAmount(in: window, includePlanned: true)
            #expect(plannedTotalAfterFutureDelete < plannedTotalAfter)
        }
    }

    @Test
    func budget_income_calculator_matches_income_service_totals() throws {
        let cal = TestUtils.utcCalendar()
        let service = try freshIncomeService(calendar: cal)

        let start = TestUtils.makeDate(2025, 9, 1)
        let end = TestUtils.makeDate(2025, 9, 30)
        let window = DateInterval(start: start, end: end)
        let ctx = CoreDataService.shared.viewContext

        // Seed incomes
        _ = try service.createIncome(source: "Paycheck", amount: 1000, date: TestUtils.makeDate(2025, 9, 5), isPlanned: true, recurrence: "weekly", recurrenceEndDate: end)
        _ = try service.createIncome(source: "Consulting", amount: 400, date: TestUtils.makeDate(2025, 9, 10), isPlanned: false)

        // Service totals
        let plannedS = try service.totalAmount(in: window, includePlanned: true)
        let actualS = try service.totalAmount(in: window, includePlanned: false)

        // Calculator totals
        let (plannedC, actualC) = try BudgetIncomeCalculator.totals(for: window, context: ctx)
        #expect(abs(plannedS - plannedC) < 0.0001)
        #expect(abs(actualS - actualC) < 0.0001)

        // Sum comparison: evaluate throwing call before using in expression
        let sumC = try BudgetIncomeCalculator.sum(in: window, context: ctx)
        #expect(abs((plannedS + actualS) - sumC) < 0.0001)
    }
}
