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

        let value = app.staticTexts["counter.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "0")

        app.buttons["counter.increment"].tap()
        app.buttons["counter.increment"].tap()
        XCTAssertEqual(value.label, "2")

        app.buttons["counter.decrement"].tap()
        XCTAssertEqual(value.label, "1")

        app.buttons["counter.reset"].tap()
        XCTAssertEqual(value.label, "0")
    }
}
