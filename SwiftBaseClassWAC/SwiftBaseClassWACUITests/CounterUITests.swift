//
//  CounterUITests.swift
//  SwiftBaseClassWACUITests
//
//  Critical-flow UI test driving the Counter screen via accessibility
//  identifiers. UI tests use XCUITest (XCTest), not Swift Testing.
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
        let counterEntry = app.buttons["home.counter"]
        XCTAssertTrue(counterEntry.waitForExistence(timeout: 5))
        counterEntry.tap()

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

    /// Waits (up to `timeout`) for `element`'s label to equal `expected`,
    /// failing only if it never settles. Robust against UI animations.
    private func assertLabel(
        _ element: XCUIElement,
        becomes expected: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result,
            .completed,
            "Expected label \"\(expected)\" but got \"\(element.label)\"",
            file: file,
            line: line
        )
    }
}
