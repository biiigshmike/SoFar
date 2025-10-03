import XCTest

final class IncomeCalendarPrefetchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testIncomeCalendarPrefetchesFutureMonths() throws {
        let app = XCUIApplication()
        // Skip onboarding, reset data, and seed income series starting Oct 1, 2025 weekly through Oct 1, 2026
        app.launchArguments.append(contentsOf: [
            "-didCompleteOnboarding", "YES",
            "-uiTestResetData",
            "-uiTestSeedIncomeCalendar"
        ])
        app.launch()

        // Open Income tab
        let incomeTab = app.tabBars.buttons["Income"].firstMatch
        XCTAssertTrue(incomeTab.waitForExistence(timeout: 5))
        incomeTab.tap()

        // Wait for calendar
        let calendar = app.otherElements["IncomeCalendar"].firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))

        // Verify that at least one day in December 2025 exposes an accessibility identifier
        // indicating it has income events (proof of prefetch without tapping a day)
        let nextMonth = app.buttons["Next Month"].firstMatch
        XCTAssertTrue(nextMonth.exists)
        let decPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "income_day_has_events_2025-12-")
        var decEventDay = app.descendants(matching: .any).matching(decPredicate).firstMatch
        var attempts = 0
        while !decEventDay.exists && attempts < 36 {
            nextMonth.tap()
            decEventDay = app.descendants(matching: .any).matching(decPredicate).firstMatch
            attempts += 1
        }
        XCTAssertTrue(decEventDay.waitForExistence(timeout: 2), "Expected at least one day with events in December 2025 after navigating months forward")

        // Also verify January 2026 gets prefetched under the dynamic horizon
        let janPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "income_day_has_events_2026-01-")
        var janEventDay = app.descendants(matching: .any).matching(janPredicate).firstMatch
        attempts = 0
        while !janEventDay.exists && attempts < 12 {
            nextMonth.tap()
            janEventDay = app.descendants(matching: .any).matching(janPredicate).firstMatch
            attempts += 1
        }
        XCTAssertTrue(janEventDay.waitForExistence(timeout: 2), "Expected at least one day with events in January 2026 after navigating months forward")
    }
}
