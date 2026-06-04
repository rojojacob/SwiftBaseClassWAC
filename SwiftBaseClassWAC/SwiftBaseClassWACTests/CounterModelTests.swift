//
//  CounterModelTests.swift
//  SwiftBaseClassWACTests
//
//  Unit tests for the domain model using the Swift Testing framework.
//

import Testing
@testable import SwiftBaseClassWAC

struct CounterModelTests {
    @Test func startsAtZeroByDefault() {
        let model = CounterModel()
        #expect(model.value == 0)
    }

    @Test func incrementAddsStep() {
        var model = CounterModel()
        model.increment(by: 3)
        #expect(model.value == 3)
    }

    @Test func decrementSubtractsStep() {
        var model = CounterModel(value: 5)
        model.decrement(by: 2)
        #expect(model.value == 3)
    }

    @Test func resetReturnsToZero() {
        var model = CounterModel(value: 42)
        model.reset()
        #expect(model.value == 0)
    }
}
