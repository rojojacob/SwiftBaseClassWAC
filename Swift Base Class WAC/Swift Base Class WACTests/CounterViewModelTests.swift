//
//  CounterViewModelTests.swift
//  Swift Base Class WACTests
//
//  Unit tests for the Counter view model. @MainActor because the view
//  model is main-actor isolated.
//

import Testing
@testable import Swift_Base_Class_WAC

@MainActor
struct CounterViewModelTests {
    @Test func startsAtConfiguredValue() {
        let viewModel = CounterViewModel(model: .init(value: 10))
        #expect(viewModel.count == 10)
        #expect(viewModel.displayText == "10")
    }

    @Test func incrementUsesConfiguredStep() {
        let viewModel = CounterViewModel(step: 5)
        viewModel.incrementTapped()
        #expect(viewModel.count == 5)
    }

    @Test func decrementUsesConfiguredStep() {
        let viewModel = CounterViewModel(model: .init(value: 5), step: 2)
        viewModel.decrementTapped()
        #expect(viewModel.count == 3)
    }

    @Test func resetIsDisabledOnlyAtZero() {
        let viewModel = CounterViewModel()
        #expect(viewModel.isResetDisabled)

        viewModel.incrementTapped()
        #expect(!viewModel.isResetDisabled)

        viewModel.resetTapped()
        #expect(viewModel.isResetDisabled)
        // `count` is a numeric counter, not a collection size.
        #expect(viewModel.count == 0) // swiftlint:disable:this empty_count
    }
}
