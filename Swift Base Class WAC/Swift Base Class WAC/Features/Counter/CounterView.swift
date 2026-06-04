//
//  CounterView.swift
//  Swift Base Class WAC
//
//  Sample vertical feature demonstrating the MVVM + @Observable pattern,
//  DesignSystem usage, and accessibility identifiers for UI testing.
//

import SwiftUI

struct CounterView: View {
    @State private var viewModel = CounterViewModel()

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Text(viewModel.displayText)
                .font(AppFont.display)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier("counter.value")

            HStack(spacing: AppSpacing.medium) {
                PrimaryButton(title: "−") {
                    viewModel.decrementTapped()
                }
                .accessibilityIdentifier("counter.decrement")

                PrimaryButton(title: "+") {
                    viewModel.incrementTapped()
                }
                .accessibilityIdentifier("counter.increment")
            }

            Button("Reset") {
                viewModel.resetTapped()
            }
            .disabled(viewModel.isResetDisabled)
            .accessibilityIdentifier("counter.reset")
        }
        .padding(AppSpacing.large)
        .navigationTitle("Counter")
    }
}

#Preview {
    NavigationStack {
        CounterView()
    }
}
