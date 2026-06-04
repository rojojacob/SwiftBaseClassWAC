/// The full audit result: findings + a derived 0–100 health score.
public struct AuditReport: Equatable, Codable, Sendable {
    public let findings: [AuditFinding]

    public init(findings: [AuditFinding]) {
        self.findings = findings
    }

    /// 100 minus the summed severity weights, floored at 0.
    public var healthScore: Int {
        let penalty = findings.reduce(0) { $0 + $1.severity.weight }
        return max(0, 100 - penalty)
    }

    /// All findings sorted by severity (critical first), then file, then line.
    public var grouped: [AuditFinding] {
        findings.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            return (lhs.line ?? 0) < (rhs.line ?? 0)
        }
    }

    /// The highest-priority `n` findings ("fix these first").
    public func topN(_ count: Int) -> [AuditFinding] {
        Array(grouped.prefix(count))
    }
}
