//
//  CounterModel.swift
//  Swift Base Class WAC
//
//  Plain value type representing the feature's domain state.
//

import Foundation

struct CounterModel: Equatable {
    private(set) var value: Int

    init(value: Int = 0) {
        self.value = value
    }

    mutating func increment(by step: Int = 1) {
        value += step
    }

    mutating func decrement(by step: Int = 1) {
        value -= step
    }

    mutating func reset() {
        value = 0
    }
}
