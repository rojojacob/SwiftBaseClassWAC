//
//  ValidationRule.swift
//  SwiftBaseClassWAC
//
//  Composable, reusable text-validation rules. Build an array of rules and
//  ask a string for its first failure message.
//
//  Example:
//      let error = email.firstValidationError([.nonEmpty(), .email()])
//

import Foundation

struct ValidationRule {
    let isValid: @Sendable (String) -> Bool
    let message: String

    static func nonEmpty(_ message: String = "This field is required.") -> ValidationRule {
        ValidationRule(
            isValid: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            message: message
        )
    }

    static func minLength(_ length: Int, message: String? = nil) -> ValidationRule {
        ValidationRule(
            isValid: { $0.count >= length },
            message: message ?? "Must be at least \(length) characters."
        )
    }

    static func email(_ message: String = "Enter a valid email address.") -> ValidationRule {
        ValidationRule(
            isValid: { value in
                let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
                return value.range(of: pattern, options: .regularExpression) != nil
            },
            message: message
        )
    }

    static func custom(_ message: String, isValid: @escaping @Sendable (String) -> Bool) -> ValidationRule {
        ValidationRule(isValid: isValid, message: message)
    }
}

extension String {
    /// Returns the message of the first failing rule, or `nil` if all pass.
    func firstValidationError(_ rules: [ValidationRule]) -> String? {
        rules.first { !$0.isValid(self) }?.message
    }

    /// `true` when the string satisfies every rule.
    func isValid(against rules: [ValidationRule]) -> Bool {
        firstValidationError(rules) == nil
    }
}
