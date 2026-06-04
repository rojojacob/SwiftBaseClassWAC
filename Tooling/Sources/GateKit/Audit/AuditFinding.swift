/// One prioritized, code-pointing audit item.
public struct AuditFinding: Equatable, Codable, Sendable {
    public let severity: AuditSeverity
    public let file: String
    public let line: Int?
    public let ruleID: String
    public let title: String // human rule name / subject
    public let detail: String // the "why"
    public let fix: String // how to fix it

    public init(
        severity: AuditSeverity,
        file: String,
        line: Int?,
        ruleID: String,
        title: String,
        detail: String,
        fix: String
    ) {
        self.severity = severity
        self.file = file
        self.line = line
        self.ruleID = ruleID
        self.title = title
        self.detail = detail
        self.fix = fix
    }
}
