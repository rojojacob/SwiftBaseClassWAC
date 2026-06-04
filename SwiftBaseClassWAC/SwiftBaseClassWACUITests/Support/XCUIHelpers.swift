//
//  XCUIHelpers.swift
//  SwiftBaseClassWACUITests
//
//  Reusable UI-test helpers (page-object style) shared across UI test cases.
//

import XCTest

extension XCUIElement {
    /// Waits for the element to exist (failing the test if it never does), then taps it.
    func tapWhenReady(
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForExistence(timeout: timeout),
            "Element \(self) never appeared",
            file: file,
            line: line
        )
        tap()
    }
}

extension XCTestCase {
    /// Waits (up to `timeout`) for `element`'s label to equal `expected`.
    /// Robust against UI animations that briefly report a stale value.
    func assertLabel(
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
