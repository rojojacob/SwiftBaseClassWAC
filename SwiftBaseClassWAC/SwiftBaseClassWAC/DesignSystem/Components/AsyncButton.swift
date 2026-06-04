//
//  AsyncButton.swift
//  SwiftBaseClassWAC
//
//  A button whose action is `async`. While the task runs it disables itself
//  and shows a progress spinner, preventing duplicate taps.
//

import SwiftUI

struct AsyncButton<Label: View>: View {
    private let role: ButtonRole?
    private let action: () async -> Void
    @ViewBuilder private let label: () -> Label

    @State private var isRunning = false

    init(
        role: ButtonRole? = nil,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(role: role) {
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            label()
                .opacity(isRunning ? 0 : 1)
                .overlay { if isRunning { ProgressView() } }
        }
        .disabled(isRunning)
    }
}

extension AsyncButton where Label == Text {
    init(_ title: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping () async -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}
