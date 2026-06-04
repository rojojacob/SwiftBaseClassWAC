import Foundation

// MARK: - Private row type (file scope to satisfy nesting rule)

private struct SwiftLintRow: Decodable {
    let file: String
    let line: Int?
    let reason: String
    let ruleID: String
    let severity: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case file, line, reason, severity, type
        case ruleID = "rule_id"
    }
}

/// Parses `swiftlint --reporter json` output into `AuditFinding`s.
public enum SwiftLintJSON {
    /// Safety-critical rules outrank a plain SwiftLint "error".
    private static let criticalRules: Set<String> = [
        "force_unwrapping", "force_try", "force_cast"
    ]

    /// Short, actionable fix hints for the rules we see most; generic fallback otherwise.
    private static let fixHints: [String: String] = [
        "force_try": "Replace `try!` with `try` + error handling (do/catch or `try?`).",
        "force_unwrapping": "Replace `!` with `guard let`/`if let` or a default.",
        "force_cast": "Replace `as!` with `as?` and handle the nil case.",
        "empty_count": "Use `isEmpty` instead of comparing `count` to 0.",
        "no_print": "Use `AppLogger` instead of `print`.",
        "view_no_networking": "Move networking into the screen's ViewModel.",
        "viewmodel_no_swiftui": "Drop `import SwiftUI` from the view model; use Observation."
    ]

    public static func findings(fromJSON data: Data, repoRoot: String) throws -> [AuditFinding] {
        let rows = try JSONDecoder().decode([SwiftLintRow].self, from: data)
        let prefix = repoRoot.hasSuffix("/") ? repoRoot : repoRoot + "/"
        return rows.map { row in
            let relative = row.file.hasPrefix(prefix) ? String(row.file.dropFirst(prefix.count)) : row.file
            let severity: AuditSeverity = criticalRules.contains(row.ruleID)
                ? .critical
                : (row.severity.lowercased() == "error" ? .high : .medium)
            return AuditFinding(
                severity: severity,
                file: relative,
                line: row.line,
                ruleID: row.ruleID,
                title: row.type,
                detail: row.reason,
                fix: fixHints[row.ruleID] ?? "See `swiftlint rules \(row.ruleID)`."
            )
        }
    }
}
