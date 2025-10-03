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

        // Wait for a known calendar control instead of the container element,
        // which can vary by platform. The navigation buttons are reliable.
        let nextMonth = app.buttons["Next Month"].firstMatch
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 8))

        // Navigate to October 2025 first, then December 2025 precisely using the month label
        func monthLabel(_ m: String) -> XCUIElement { app.staticTexts[m] }
        var prev = app.buttons["Previous Month"].firstMatch
        var attempts = 0
        while !monthLabel("October 2025").exists && attempts < 24 {
            prev.tap()
            attempts += 1
            prev = app.buttons["Previous Month"].firstMatch
        }
        if !monthLabel("October 2025").exists {
            var next = app.buttons["Next Month"].firstMatch
            attempts = 0
            while !monthLabel("October 2025").exists && attempts < 48 {
                next.tap()
                attempts += 1
                next = app.buttons["Next Month"].firstMatch
            }
        }
        XCTAssertTrue(monthLabel("October 2025").waitForExistence(timeout: 3))
        app.buttons["Next Month"].firstMatch.tap()
        app.buttons["Next Month"].firstMatch.tap()
        XCTAssertTrue(monthLabel("December 2025").waitForExistence(timeout: 3))

        // Tap a Wednesday in December 2025. Oct 1 2025 is Wednesday, so weekly recurrence hits Dec 3/10/17/24/31.
        // We’ll try a few day numbers and assert the selected day list shows the seeded income source.
        let candidateDays = ["3", "10", "17", "24", "31"]
        var found = false
        for day in candidateDays {
            let candidates = app.staticTexts.matching(NSPredicate(format: "label == %@", day))
            for i in 0..<min(candidates.count, 8) {
                let e = candidates.element(boundBy: i)
                if e.exists && e.isHittable {
                    e.tap()
                    let row = app.staticTexts["UI Test Weekly Income"].firstMatch
                    if row.waitForExistence(timeout: 1.0) {
                        found = true
                        break
                    }
                }
            }
            if found { break }
        }
        XCTAssertTrue(found, "Failed to find a December 2025 day showing the seeded weekly income after prefetch")
    }
}
