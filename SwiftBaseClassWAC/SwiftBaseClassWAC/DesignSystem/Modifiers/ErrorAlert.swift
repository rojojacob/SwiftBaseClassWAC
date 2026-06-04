//
//  ErrorAlert.swift
//  SwiftBaseClassWAC
//
//  `.errorAlert(_:)` — binds an optional `Error` to a standard alert. Set the
//  binding to a non-nil error to present it; dismissing clears it.
//

import SwiftUI

private struct ErrorAlertModifier: ViewModifier {
    @Binding var error: (any Error)?

    func body(content: Content) -> some View {
        content.alert(
            "Something went wrong",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { _ in
            Button("OK", role: .cancel) { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<(any Error)?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
