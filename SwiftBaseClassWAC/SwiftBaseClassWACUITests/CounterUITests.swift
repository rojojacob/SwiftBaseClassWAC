//
//  CounterUITests.swift
//  SwiftBaseClassWACUITests
//
//  Critical-flow UI test driving the Counter screen via accessibility
//  identifiers. UI tests use XCUITest (XCTest), not Swift Testing.
//  Shared helpers (`tapWhenReady`, `assertLabel`) live in XCUIHelpers.swift.
//

import XCTest

final class CounterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testIncrementAndResetFlow() {
        let app = XCUIApplication()
        app.launch()

        // Navigate from Home into the Counter feature.
        app.buttons["home.counter"].tapWhenReady()

        let value = app.staticTexts["counter.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        assertLabel(value, becomes: "0")

        // Wait for the label to settle after each tap: the value uses an
        // animated numeric content transition, so reading `.label` immediately
        // after a tap can race the animation and observe the previous value.
        app.buttons["counter.increment"].tap()
        assertLabel(value, becomes: "1")

        app.buttons["counter.increment"].tap()
        assertLabel(value, becomes: "2")

        app.buttons["counter.decrement"].tap()
        assertLabel(value, becomes: "1")

        app.buttons["counter.reset"].tap()
        assertLabel(value, becomes: "0")
    }

    /// Documents the Counter's edge behavior as-is (the feature is reference
    /// scaffolding, intentionally left unchanged): Reset is disabled at zero, the
    /// value has no floor and goes negative, and Reset re-enables once it differs
    /// from zero.
    @MainActor
    func testEdgeStatesNegativeAndDisabledReset() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["home.counter"].tapWhenReady()

        let value = app.staticTexts["counter.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        assertLabel(value, becomes: "0")
        // Edge: Reset is non-interactive while the value is zero.
        XCTAssertFalse(app.buttons["counter.reset"].isEnabled, "Reset should be disabled at 0")

        // Edge: the counter has no floor — decrementing past zero goes negative.
        app.buttons["counter.decrement"].tap()
        assertLabel(value, becomes: "-1")
        XCTAssertTrue(app.buttons["counter.reset"].isEnabled, "Reset should enable once value != 0")
        app.buttons["counter.decrement"].tap()
        assertLabel(value, becomes: "-2")
        attachScreenshot(of: app, named: "Counter-Negative")

        // Reset returns to zero and disables again.
        app.buttons["counter.reset"].tap()
        assertLabel(value, becomes: "0")
        XCTAssertFalse(app.buttons["counter.reset"].isEnabled, "Reset should disable again at 0")
    }
}
