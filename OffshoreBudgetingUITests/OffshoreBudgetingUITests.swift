//
//  OffshoreBudgetingUITests.swift
//  OffshoreBudgetingUITests
//
//  Created by Michael Brown on 8/11/25.
//
//  UI tests skip onboarding by passing "-didCompleteOnboarding YES" to the
//  application process. Tests that validate compact layouts also force the
//  simulator into landscape so the tab scaffold must scroll when controls are
//  near the edges of the viewport.
//

import XCTest
import Foundation
import CoreGraphics

final class OffshoreBudgetingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch Helpers

    /// Launches the application so tests start on ``RootTabView``.
    ///
    /// The helper centralizes the onboarding override and any platform-specific
    /// orientation tweaks so future tests automatically benefit from the
    /// standardized environment.
    @MainActor
    @discardableResult
    private func launchAppSkippingOnboarding(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        if !app.launchArguments.contains("-didCompleteOnboarding") {
            app.launchArguments.append(contentsOf: ["-didCompleteOnboarding", "YES"])
        }

        for argument in extraArguments where !app.launchArguments.contains(argument) {
            app.launchArguments.append(argument)
        }

        app.launch()

        #if os(iOS)
        let device = XCUIDevice.shared
        if device.orientation != .landscapeLeft {
            device.orientation = .landscapeLeft
        }
        #endif

        waitForTabBar(in: app)
        return app
    }

    @MainActor
    private func waitForTabBar(in app: XCUIApplication, timeout: TimeInterval = 5) {
        let homeTab = tabButton(for: .home, in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: timeout))
    }

    // MARK: - Root Tab Controls

    private enum RootTab: String, CaseIterable {
        case home = "Home"
        case income = "Income"
        case cards = "Cards"
        case presets = "Presets"
        case settings = "Settings"
    }

    @MainActor
    private func openTab(_ tab: RootTab, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let control = tabButton(for: tab, in: app)
        XCTAssertTrue(control.waitForExistence(timeout: 5), file: file, line: line)
        control.tap()
    }

    private func tabButton(for tab: RootTab, in app: XCUIApplication) -> XCUIElement {
        let label = tab.rawValue
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.exists { return tabBarButton }

        let predicate = NSPredicate(format: "label == %@", label)
        let fallback = app.buttons.matching(predicate).firstMatch
        if fallback.exists { return fallback }

        return app.descendants(matching: .button)
            .matching(predicate)
            .firstMatch
    }

    @MainActor
    private func assertKeyControlHittable(for tab: RootTab, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        switch tab {
        case .home:
            let primaryAction = app.buttons["Create a budget"].firstMatch
            XCTAssertTrue(primaryAction.waitForExistence(timeout: 5), file: file, line: line)
            ensureElementHittable(primaryAction, in: app, file: file, line: line)
        case .income:
            let calendar = app.otherElements["IncomeCalendar"].firstMatch
            XCTAssertTrue(calendar.waitForExistence(timeout: 5), file: file, line: line)
            ensureElementHittable(calendar, in: app, file: file, line: line)
        case .cards:
            let addCardButton = app.buttons["Add Card"].firstMatch
            XCTAssertTrue(addCardButton.waitForExistence(timeout: 5), file: file, line: line)
            ensureElementHittable(addCardButton, in: app, file: file, line: line)
        case .presets:
            let addPresetButton = app.buttons["Add Preset Planned Expense"].firstMatch
            if addPresetButton.waitForExistence(timeout: 3) {
                ensureElementHittable(addPresetButton, in: app, file: file, line: line)
            } else {
                let emptyStateButton = app.buttons["Add Preset"].firstMatch
                XCTAssertTrue(emptyStateButton.waitForExistence(timeout: 5), file: file, line: line)
                ensureElementHittable(emptyStateButton, in: app, file: file, line: line)
            }
        case .settings:
            var firstToggle = app.descendants(matching: .switch).firstMatch
            if !firstToggle.exists {
                firstToggle = app.descendants(matching: .checkBox).firstMatch
            }
            if !firstToggle.exists {
                let predicate = NSPredicate(format: "label CONTAINS[c] %@", "Confirm Before Deleting")
                firstToggle = app.buttons.matching(predicate).firstMatch
            }
            XCTAssertTrue(firstToggle.waitForExistence(timeout: 5), file: file, line: line)
            ensureElementHittable(firstToggle, in: app, file: file, line: line)
        }
    }

    @MainActor
    private func ensureElementHittable(_ element: XCUIElement, in app: XCUIApplication, file: StaticString, line: UInt) {
        #if os(iOS)
        if !element.isHittable {
            attemptScrolling(in: app, toReveal: element)
        }
        #endif
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    #if os(iOS)
    @MainActor
    private func attemptScrolling(in app: XCUIApplication, toReveal element: XCUIElement, maxAttempts: Int = 4) {
        let containers: [XCUIElement] = [
            app.scrollViews.firstMatch,
            app.collectionViews.firstMatch,
            app.tables.firstMatch
        ].filter { $0.exists }

        guard !containers.isEmpty else { return }

        for container in containers {
            var attempts = 0
            while !element.isHittable && attempts < maxAttempts {
                container.swipeUp()
                attempts += 1
            }

            attempts = 0
            while !element.isHittable && attempts < maxAttempts {
                container.swipeDown()
                attempts += 1
            }

            if element.isHittable { return }
        }
    }
    #endif

    // MARK: - Tab Visibility Tests

    #if os(iOS)
    @MainActor
    func testHomePrimaryActionHittableInLandscape() throws {
        let app = launchAppSkippingOnboarding()
        openTab(.home, in: app)
        assertKeyControlHittable(for: .home, in: app)
    }

    @MainActor
    func testIncomeCalendarHittableInLandscape() throws {
        let app = launchAppSkippingOnboarding()
        openTab(.income, in: app)
        assertKeyControlHittable(for: .income, in: app)
    }

    @MainActor
    func testCardsAddButtonHittableInLandscape() throws {
        let app = launchAppSkippingOnboarding()
        openTab(.cards, in: app)
        assertKeyControlHittable(for: .cards, in: app)
    }

    @MainActor
    func testPresetsAddButtonHittableInLandscape() throws {
        let app = launchAppSkippingOnboarding()
        openTab(.presets, in: app)
        assertKeyControlHittable(for: .presets, in: app)
    }

    @MainActor
    func testSettingsFirstToggleHittableInLandscape() throws {
        let app = launchAppSkippingOnboarding()
        openTab(.settings, in: app)
        assertKeyControlHittable(for: .settings, in: app)
    }
    #endif

    // MARK: - macOS / Catalyst Adaptivity

    #if targetEnvironment(macCatalyst) || os(macOS)
    @MainActor
    func testKeyControlsVisibleInShortMacWindow() throws {
        let app = launchAppSkippingOnboarding()
        resizeWindowToShortHeight(app)

        for tab in RootTab.allCases {
            openTab(tab, in: app)
            assertKeyControlHittable(for: tab, in: app)
        }
    }

    @MainActor
    private func resizeWindowToShortHeight(_ app: XCUIApplication, targetHeight: CGFloat = 480) {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 5) else { return }

        let frame = window.frame
        let minimumHeight = max(360, targetHeight)
        let desiredHeight = min(minimumHeight, frame.height)
        let delta = frame.height - desiredHeight
        guard delta > 10 else { return }

        let bottomEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0))
        let targetPoint = bottomEdge.withOffset(CGVector(dx: 0, dy: -delta))
        bottomEdge.press(forDuration: 0.1, thenDragTo: targetPoint)
    }
    #endif
}
