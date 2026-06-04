//
//  CounterViewModel.swift
//  Swift Base Class WAC
//
//  Observable view model (iOS 17+ @Observable macro) holding presentation
//  logic for the Counter feature. Views observe this; it owns the model.
//

import Observation

@Observable
@MainActor
final class CounterViewModel {
    private var model: CounterModel

    /// Amount each tap changes the counter by.
    let step: Int

    init(model: CounterModel = .init(), step: Int = 1) {
        self.model = model
        self.step = step
    }

    // MARK: - Derived state for the View

    var count: Int {
        model.value
    }

    var displayText: String {
        "\(model.value)"
    }

    var isResetDisabled: Bool {
        model.value == 0
    }

    // MARK: - Intents

    func incrementTapped() {
        model.increment(by: step)
    }

    func decrementTapped() {
        model.decrement(by: step)
    }

    func resetTapped() {
        model.reset()
    }
}
