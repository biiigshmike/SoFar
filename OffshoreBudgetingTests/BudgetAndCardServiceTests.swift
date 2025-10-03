import Foundation
import Testing
@testable import Offshore

@MainActor
struct BudgetAndCardServiceTests {

    private func newServices() throws -> (BudgetService, CardService) {
        _ = try TestUtils.resetStore()
        return (BudgetService(), CardService())
    }

    @Test
    func budget_crud_and_active_fetch() throws {
        let (budgetService, _) = try newServices()
        let cal = TestUtils.utcCalendar()
        let start = TestUtils.makeDate(2025, 9, 1)
        let end = TestUtils.makeDate(2025, 9, 30)

        // Create budget
        let budget = try budgetService.createBudget(name: "September Budget",
                                                    startDate: start,
                                                    endDate: end,
                                                    isRecurring: true,
                                                    recurrenceType: "FREQ=MONTHLY",
                                                    recurrenceEndDate: TestUtils.makeDate(2026, 9, 1),
                                                    parentID: nil)
        #expect(budget.name == "September Budget")

        // Fetch active budget on date inside range
        let mid = TestUtils.makeDate(2025, 9, 15)
        let active = try budgetService.fetchActiveBudget(on: mid)
        #expect(active?.objectID == budget.objectID)

        // Update name and dates
        let newEnd = TestUtils.makeDate(2025, 10, 5)
        try budgetService.updateBudget(budget,
                                       name: "Sept Budget",
                                       dates: (start: start, end: newEnd),
                                       isRecurring: true,
                                       recurrenceType: "FREQ=MONTHLY",
                                       recurrenceEndDate: TestUtils.makeDate(2026, 10, 1))
        #expect(budget.name == "Sept Budget")

        // Projected dates using recurrence
        let interval = DateInterval(start: start, end: TestUtils.makeDate(2026, 1, 1))
        let dates = budgetService.projectedDates(for: budget, in: interval, calendar: cal)
        #expect(dates.first == start)
        #expect(dates.contains(TestUtils.makeDate(2025, 12, 1)))

        // Delete budget
        try budgetService.deleteBudget(budget)
        let none = try budgetService.fetchActiveBudget(on: mid)
        #expect(none == nil)
    }

    @Test
    func card_crud_and_budget_links() throws {
        let (budgetService, cardService) = try newServices()

        // Budgets
        let b1 = try budgetService.createBudget(name: "Aug",
                                                startDate: TestUtils.makeDate(2025, 8, 1),
                                                endDate: TestUtils.makeDate(2025, 8, 31))
        let b2 = try budgetService.createBudget(name: "Sep",
                                                startDate: TestUtils.makeDate(2025, 9, 1),
                                                endDate: TestUtils.makeDate(2025, 9, 30))

        // Create cards
        let c1 = try cardService.createCard(name: "Amex")
        let c2 = try cardService.createCard(name: "Visa")
        #expect(try cardService.fetchAllCards().count == 2)

        // Attach c1 to both budgets; c2 to Sep only
        try cardService.attachCard(c1, toBudgetsWithIDs: [b1.id!, b2.id!])
        try cardService.attachCard(c2, toBudgetsWithIDs: [b2.id!])

        // Fetch for budget ID
        let augCards = try cardService.fetchCards(forBudgetID: b1.id!)
        #expect(augCards.map { $0.name ?? "" } == ["Amex"]) // only c1
        let sepCards = try cardService.fetchCards(forBudgetID: b2.id!)
        #expect(sepCards.map { $0.name ?? "" } == ["Amex", "Visa"]) // sorted A→Z

        // Rename c2
        try cardService.renameCard(c2, to: "Visa Platinum")
        #expect(c2.name == "Visa Platinum")

        // Replace c1 links to only Sep
        try cardService.replaceCard(c1, budgetsWithIDs: [b2.id!])
        let augCards2 = try cardService.fetchCards(forBudgetID: b1.id!)
        #expect(augCards2.isEmpty)

        // Detach c2 from Sep
        try cardService.detachCard(c2, fromBudgetsWithIDs: [b2.id!])
        let sepCards2 = try cardService.fetchCards(forBudgetID: b2.id!)
        #expect(sepCards2.map { $0.name ?? "" } == ["Amex"]) // only c1 now

        // Delete card
        try cardService.deleteCard(c1)
        #expect(try cardService.fetchAllCards().count == 1)
    }
}
