import Foundation
import Testing
@testable import Offshore

@MainActor
struct UnplannedExpenseServiceTests {

    private func bootstrap() throws -> (Budget, Card, ExpenseCategory, UnplannedExpenseService) {
        _ = try TestUtils.resetStore()
        let bs = BudgetService()
        let cs = CardService()
        let ecs = ExpenseCategoryService()
        let us = UnplannedExpenseService()

        let budget = try bs.createBudget(name: "Sep 2025",
                                         startDate: TestUtils.makeDate(2025, 9, 1),
                                         endDate: TestUtils.makeDate(2025, 9, 30))
        let card = try cs.createCard(name: "Daily Card")
        try cs.attachCard(card, toBudgetsWithIDs: [budget.id!])
        let cat = try ecs.addCategory(name: "Groceries", color: "#00FF00")
        return (budget, card, cat, us)
    }

    @Test
    func crud_fetch_totals_split_delete() throws {
        let (budget, card, category, service) = try bootstrap()
        let d1 = TestUtils.makeDate(2025, 9, 3)
        let d2 = TestUtils.makeDate(2025, 9, 10)
        let d3 = TestUtils.makeDate(2025, 9, 27)
        let interval = DateInterval(start: TestUtils.makeDate(2025, 9, 1), end: TestUtils.makeDate(2025, 9, 30))

        // Create
        let e1 = try service.create(descriptionText: "Market",
                                     amount: 42.50,
                                     date: d1,
                                     cardID: card.id!,
                                     categoryID: category.id!)
        #expect(e1.amount == 42.50)

        // Update amount/date/description
        try service.update(e1,
                           description: "Market Run",
                           amount: 45.0,
                           date: d2)
        #expect(e1.amount == 45.0)
        #expect(e1.transactionDate == d2)

        // Create another in same month
        let _ = try service.create(descriptionText: "Snacks",
                                   amount: 15.25,
                                   date: d3,
                                   cardID: card.id!,
                                   categoryID: category.id!)

        // Fetch by card / category / budget
        let byCard = try service.fetchForCard(card.id!, in: interval)
        #expect(byCard.count == 2)

        let byCategory = try service.fetchForCategory(category.id!, in: interval)
        #expect(byCategory.count == 2)

        let byBudget = try service.fetchForBudget(budget.id!, in: interval)
        #expect(byBudget.count == 2)

        // Totals
        let totalCard = try service.totalForCard(card.id!, in: interval)
        #expect(abs(totalCard - (45.0 + 15.25)) < 0.0001)

        let totalBudget = try service.totalForBudget(budget.id!, in: interval)
        #expect(abs(totalBudget - totalCard) < 0.0001)

        // Split first expense into two
        let parts = [
            UnplannedExpenseService.SplitPart(amount: 20.0, categoryID: category.id, cardID: nil, descriptionSuffix: "(food)"),
            UnplannedExpenseService.SplitPart(amount: 25.0, categoryID: category.id, cardID: nil, descriptionSuffix: "(household)")
        ]
        let children = try service.split(e1, parts: parts, zeroOutParent: true)
        #expect(children.count == 2)
        #expect(abs((children.first?.amount ?? 0) - 20.0) < 0.0001)
        #expect(e1.amount == 0) // parent zeroed out

        // Ensure relationship link so children(of:) (which uses parentExpense relation) can find them
        for c in children { try service.addChild(e1, child: c) }

        // Verify children fetch
        let parentID = e1.id!
        let kids = try service.children(of: parentID)
        #expect(kids.count == 2)

        // Delete with cascade (removes children too)
        try service.delete(e1, cascadeChildren: true)
        let kidsAfter = try service.children(of: parentID)
        #expect(kidsAfter.isEmpty)

        // Delete all for card
        try service.deleteAllForCard(card.id!)
        let none = try service.fetchAll()
        #expect(none.isEmpty)
    }

    @Test
    func events_and_grouping_with_recurrence() throws {
        let (budget, card, category, service) = try bootstrap()
        let start = TestUtils.makeDate(2025, 9, 1)
        let end = TestUtils.makeDate(2025, 9, 30)
        let interval = DateInterval(start: start, end: end)

        // Weekly recurring small purchase starting Sep 2
        let base = TestUtils.makeDate(2025, 9, 2)
        _ = try service.create(descriptionText: "Coffee",
                               amount: 3.50,
                               date: base,
                               cardID: card.id!,
                               categoryID: category.id!,
                               recurrence: "weekly",
                               recurrenceEnd: end)

        let events = try service.events(in: interval, includeProjectedRecurrences: true)
        #expect(events.contains { Calendar.current.isDate($0.date, inSameDayAs: base) })
        #expect(events.count >= 4) // 4 Tuesdays in Sep 2025

        let grouped = try service.eventsByDay(in: interval)
        #expect(grouped.keys.contains(Calendar.current.startOfDay(for: base)))

        // Totals remain correct via budget link
        // Persisted totals only include stored rows (base occurrence),
        // while events include projected recurrences for UI.
        let totalBudget = try service.totalForBudget(budget.id!, in: interval)
        #expect(abs(totalBudget - 3.50) < 0.0001)
    }
}
