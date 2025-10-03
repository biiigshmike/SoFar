import Foundation
import CoreData
import Testing
@testable import Offshore

@MainActor
struct PlannedExpenseServiceTests {

    private func bootstrap() throws -> (Budget, Budget, ExpenseCategory, PlannedExpenseService, NSManagedObjectContext) {
        let container = try TestUtils.resetStore()
        let ctx = container.viewContext
        let bs = BudgetService()
        let ecs = ExpenseCategoryService()
        let ps = PlannedExpenseService()

        let b1 = try bs.createBudget(name: "Sep",
                                     startDate: TestUtils.makeDate(2025, 9, 1),
                                     endDate: TestUtils.makeDate(2025, 9, 30))
        let b2 = try bs.createBudget(name: "Oct",
                                     startDate: TestUtils.makeDate(2025, 10, 1),
                                     endDate: TestUtils.makeDate(2025, 10, 31))
        let cat = try ecs.addCategory(name: "Rent", color: "#AA00FF")
        return (b1, b2, cat, ps, ctx)
    }

    @Test
    func fetch_totals_update_move_delete_planned() throws {
        let (b1, b2, cat, ps, ctx) = try bootstrap()

        // Create two planned expenses directly in context to satisfy required relationships
        let p1 = PlannedExpense(context: ctx)
        p1.id = UUID()
        p1.descriptionText = "Rent"
        p1.plannedAmount = 1200
        p1.actualAmount = 0
        p1.transactionDate = TestUtils.makeDate(2025, 9, 3)
        p1.isGlobal = false
        p1.globalTemplateID = nil
        p1.budget = b1
        p1.expenseCategory = cat

        let p2 = PlannedExpense(context: ctx)
        p2.id = UUID()
        p2.descriptionText = "Utilities"
        p2.plannedAmount = 180
        p2.actualAmount = 150
        p2.transactionDate = TestUtils.makeDate(2025, 9, 12)
        p2.isGlobal = false
        p2.globalTemplateID = nil
        p2.budget = b1
        p2.expenseCategory = cat

        try ctx.save()

        // Fetch for budget & interval
        let allB1 = try ps.fetchForBudget(b1.id!)
        #expect(allB1.count == 2)

        let interval = DateInterval(start: TestUtils.makeDate(2025, 9, 1), end: TestUtils.makeDate(2025, 9, 30))
        let inRange = try ps.fetchForBudget(b1.id!, in: interval)
        #expect(inRange.count == 2)

        // Totals for budget
        let (planned, actual) = try ps.totalsForBudget(b1.id!, in: interval)
        #expect(abs(planned - (1200 + 180)) < 0.0001)
        #expect(abs(actual - 150) < 0.0001)

        // Update fields through service
        try ps.update(p2, titleOrDescription: "Electric & Water", plannedAmount: 200, actualAmount: 160)
        #expect(p2.plannedAmount == 200)
        #expect(p2.actualAmount == 160)

        // Move p2 to next budget
        try ps.move(p2, toBudgetID: b2.id!)
        #expect(p2.budget?.objectID == b2.objectID)

        // Adjust actual amount
        try ps.adjustActualAmount(p2, delta: -10)
        #expect(p2.actualAmount == 150)

        // Delete one, then delete all for budget
        try ps.delete(p1)
        let afterDeleteOne = try ps.fetchForBudget(b1.id!)
        #expect(afterDeleteOne.count == 0) // p2 moved out; p1 deleted

        // Create another to exercise deleteAll
        let p3 = PlannedExpense(context: ctx)
        p3.id = UUID()
        p3.descriptionText = "Phone"
        p3.plannedAmount = 60
        p3.actualAmount = 50
        p3.transactionDate = TestUtils.makeDate(2025, 9, 20)
        p3.budget = b2
        p3.expenseCategory = cat
        try ctx.save()

        try ps.deleteAllForBudget(b2.id!)
        let none = try ps.fetchForBudget(b2.id!)
        #expect(none.isEmpty)
    }
}
