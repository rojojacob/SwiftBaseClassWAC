//
//  OnFirstAppear.swift
//  SwiftBaseClassWAC
//
//  `.onFirstAppear { }` — runs an action only the first time a view appears,
//  unlike `.onAppear` which fires on every appearance (tab switches, pushes…).
//

import SwiftUI

private struct OnFirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

extension View {
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }
}
