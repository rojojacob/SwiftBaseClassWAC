//
//  PostsUITests.swift
//  SwiftBaseClassWACUITests
//
//  Edge-state regression for the networked Posts feature. Each state is driven
//  deterministically (no real network) by a DEBUG-only stub selected via launch
//  argument — see UITestStubArgument in Dependencies.swift. Every test attaches
//  a screenshot so the run is also a visual record of each state.
//

import XCTest

final class PostsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Posts → every post's detail (#1, #2, #3), returning to the list each time.
    @MainActor
    func testOpensEveryPostDetail() {
        let app = launch(with: "-uiTestStubAPI")
        openPosts(app)
        for id in 1 ... 3 {
            app.cells.element(boundBy: id - 1).tap()
            XCTAssertTrue(
                app.navigationBars["Post #\(id)"].waitForExistence(timeout: 5),
                "Detail for post #\(id) never appeared"
            )
            attachScreenshot(of: app, named: "PostDetail-\(id)")
            app.navigationBars.buttons.element(boundBy: 0).tap() // back to Posts
            XCTAssertTrue(app.navigationBars["Posts"].waitForExistence(timeout: 5))
        }
    }

    /// Pull-to-refresh keeps the list populated.
    @MainActor
    func testPullToRefreshKeepsPosts() {
        let app = launch(with: "-uiTestStubAPI")
        openPosts(app)
        let first = app.staticTexts["First post"]
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Stubbed posts never loaded")
        app.swipeDown() // trigger .refreshable
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Posts vanished after refresh")
        attachScreenshot(of: app, named: "Posts-Refreshed")
    }

    /// Empty response shows the "No Posts" placeholder.
    @MainActor
    func testEmptyState() {
        let app = launch(with: "-uiTestPostsEmpty")
        openPosts(app)
        XCTAssertTrue(
            app.staticTexts["No Posts"].waitForExistence(timeout: 5),
            "Empty-state placeholder never appeared"
        )
        attachScreenshot(of: app, named: "Posts-Empty")
    }

    /// A failed request surfaces the shared error alert.
    @MainActor
    func testErrorState() {
        let app = launch(with: "-uiTestPostsError")
        openPosts(app)
        XCTAssertTrue(
            app.alerts["Something went wrong"].waitForExistence(timeout: 5),
            "Error alert never appeared"
        )
        attachScreenshot(of: app, named: "Posts-Error")
    }

    @MainActor
    private func launch(with argument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [argument]
        app.launch()
        return app
    }

    @MainActor
    private func openPosts(_ app: XCUIApplication) {
        app.buttons["home.posts"].tapWhenReady()
        XCTAssertTrue(app.navigationBars["Posts"].waitForExistence(timeout: 5), "Posts screen never appeared")
    }
}
