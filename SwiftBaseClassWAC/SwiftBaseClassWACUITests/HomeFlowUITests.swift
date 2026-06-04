//
//  HomeFlowUITests.swift
//  SwiftBaseClassWACUITests
//
//  High-level end-to-end regression for the whole navigation flow:
//  Home → Counter, and Home → Posts → PostDetail. Drives the app through
//  accessibility identifiers and captures a screenshot of every screen, so a
//  run doubles as a visual record (the "continuous observation"). The networked
//  Posts screen is made deterministic with the `-uiTestStubAPI` launch argument
//  (DEBUG-only seam in Dependencies.swift), so this suite never depends on the
//  network. UI tests use XCUITest (XCTest), not Swift Testing; shared helpers
//  (`tapWhenReady`, `assertLabel`) live in XCUIHelpers.swift.
//

import XCTest

final class HomeFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Walks every screen in order, asserting each one and attaching a
    /// screenshot so the result bundle is a visual regression record.
    @MainActor
    func testWalksEveryScreenAndCapturesScreenshots() {
        let app = XCUIApplication()
        // Hermetic, offline Posts data. Must match `uiTestStubArgument` in Dependencies.swift.
        app.launchArguments = ["-uiTestStubAPI"]
        app.launch()

        assertHome(app)
        assertCounter(app)
        assertPosts(app)
        assertPostDetail(app)
    }

    @MainActor
    private func assertHome(_ app: XCUIApplication) {
        let counterRow = app.buttons["home.counter"]
        XCTAssertTrue(counterRow.waitForExistence(timeout: 10), "Home screen never appeared")
        XCTAssertTrue(app.buttons["home.posts"].exists, "Posts row missing on Home")
        attachScreenshot(of: app, named: "01-Home")
    }

    @MainActor
    private func assertCounter(_ app: XCUIApplication) {
        app.buttons["home.counter"].tapWhenReady()
        let value = app.staticTexts["counter.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5), "Counter screen never appeared")
        assertLabel(value, becomes: "0")
        attachScreenshot(of: app, named: "02-Counter")
        app.navigationBars.buttons.element(boundBy: 0).tap() // back to Home
    }

    @MainActor
    private func assertPosts(_ app: XCUIApplication) {
        app.buttons["home.posts"].tapWhenReady()
        XCTAssertTrue(app.navigationBars["Posts"].waitForExistence(timeout: 5), "Posts screen never appeared")
        XCTAssertTrue(app.staticTexts["First post"].waitForExistence(timeout: 5), "Stubbed posts never loaded")
        attachScreenshot(of: app, named: "03-Posts")
    }

    @MainActor
    private func assertPostDetail(_ app: XCUIApplication) {
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Post #1"].waitForExistence(timeout: 5), "Post detail never appeared")
        attachScreenshot(of: app, named: "04-PostDetail")
    }
}
