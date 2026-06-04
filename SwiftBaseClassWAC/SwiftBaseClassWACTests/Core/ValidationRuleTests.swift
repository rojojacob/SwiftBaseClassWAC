//
//  ValidationRuleTests.swift
//  SwiftBaseClassWACTests
//

import Testing
@testable import SwiftBaseClassWAC

struct ValidationRuleTests {
    @Test func nonEmptyRejectsBlankAndWhitespace() {
        #expect("".firstValidationError([.nonEmpty()]) != nil)
        #expect("   ".firstValidationError([.nonEmpty()]) != nil)
        #expect("ok".firstValidationError([.nonEmpty()]) == nil)
    }

    @Test func emailValidatesFormat() {
        #expect("user@example.com".isValid(against: [.email()]))
        #expect(!"not-an-email".isValid(against: [.email()]))
    }

    @Test func minLengthEnforcesCount() {
        #expect("12345".isValid(against: [.minLength(5)]))
        #expect(!"1234".isValid(against: [.minLength(5)]))
    }

    @Test func returnsFirstFailingRuleMessage() {
        let message = "".firstValidationError([.nonEmpty("required"), .email("bad email")])
        #expect(message == "required")
    }
}
