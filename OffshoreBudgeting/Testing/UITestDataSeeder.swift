import Foundation

enum UITestDataSeeder {
    static func applyIfNeeded() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let shouldResetData = arguments.contains("-uiTestResetData")
        let shouldSeedHomeBudget = arguments.contains("-uiTestSeedHomeBudget")
        let shouldSeedIncomeCalendar = arguments.contains("-uiTestSeedIncomeCalendar")

        guard shouldResetData || shouldSeedHomeBudget else { return }

        Task(priority: .userInitiated) {
            await CoreDataService.shared.waitUntilStoresLoaded(timeout: 5.0, pollInterval: 0.05)

            if shouldResetData {
                await wipeAllDataForUITests()
            }

            if shouldSeedHomeBudget {
                await seedHomeBudget()
            }
            if shouldSeedIncomeCalendar {
                await seedIncomeCalendar()
            }
        }
#endif
    }

#if DEBUG
    @MainActor
    private static func wipeAllDataForUITests() {
        do {
            try CoreDataService.shared.wipeAllData()
        } catch {
            assertionFailure("Failed to reset data for UI tests: \(error)")
        }
    }

    @MainActor
    private static func seedHomeBudget(date: Date = Date(), calendar: Calendar = .current) {
        let budgetService = BudgetService()
        let period = BudgetPeriod.monthly
        let (start, end) = period.range(containing: date)

        do {
            let existing = try budgetService.fetchAllBudgets(sortByStartDateDescending: false)
            if existing.contains(where: { existingBudget in
                guard let startDate = existingBudget.startDate, let endDate = existingBudget.endDate else { return false }
                return calendar.isDate(startDate, inSameDayAs: start) && calendar.isDate(endDate, inSameDayAs: end)
            }) {
                return
            }

            _ = try budgetService.createBudget(
                name: "UI Test Budget",
                startDate: start,
                endDate: end,
                isRecurring: false,
                recurrenceType: nil,
                recurrenceEndDate: nil,
                parentID: nil
            )
        } catch {
            assertionFailure("Failed to seed UI test budget: \(error)")
        }
    }
#endif
}

#if DEBUG
extension UITestDataSeeder {
    @MainActor
    fileprivate static func seedIncomeCalendar() {
        let service = IncomeService(calendar: {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            return cal
        }())

        let start = {
            var comps = DateComponents(); comps.year = 2025; comps.month = 10; comps.day = 1; comps.hour = 12; comps.minute = 0; comps.timeZone = TimeZone(secondsFromGMT: 0)
            return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
        }()
        let end = {
            var comps = DateComponents(); comps.year = 2026; comps.month = 10; comps.day = 1; comps.hour = 12; comps.minute = 0; comps.timeZone = TimeZone(secondsFromGMT: 0)
            return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
        }()

        do {
            // One simple weekly planned income series so dots appear in future months
            _ = try service.createIncome(
                source: "UI Test Weekly Income",
                amount: 100,
                date: start,
                isPlanned: true,
                recurrence: "weekly",
                recurrenceEndDate: end
            )
        } catch {
            assertionFailure("Failed to seed income calendar data: \(error)")
        }
    }
}
#endif
