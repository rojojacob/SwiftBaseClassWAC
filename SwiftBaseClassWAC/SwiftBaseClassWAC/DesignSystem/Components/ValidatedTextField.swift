//
//  ValidatedTextField.swift
//  SwiftBaseClassWAC
//
//  A labeled text field that validates against `ValidationRule`s and shows an
//  inline error once the user has edited it. Supports a secure (password) mode.
//

import SwiftUI

struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    var rules: [ValidationRule] = []
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    @State private var hasEdited = false
    @FocusState private var isFocused: Bool

    private var errorMessage: String? {
        hasEdited ? text.firstValidationError(rules) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColor.secondaryText)

            field
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .accessibilityIdentifier("field.\(title)")
                .onChange(of: isFocused) { _, focused in
                    if !focused { hasEdited = true }
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field.\(title).error")
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(title, text: $text)
        } else {
            TextField(title, text: $text)
        }
    }
}
