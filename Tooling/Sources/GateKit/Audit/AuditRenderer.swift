/// Renders an `AuditReport` to Markdown and GitHub Actions annotation lines.
public enum AuditRenderer {
    public static func markdown(_ report: AuditReport, topN: Int) -> String {
        var out = "# Gate Audit Report\n\n"
        out += "**Health: \(report.healthScore)/100** — \(report.findings.count) finding(s)\n\n"

        let top = report.topN(topN)
        if !top.isEmpty {
            out += "## Fix these first\n\n"
            for finding in top {
                out += "1. **[\(finding.severity.label)]** `\(location(finding))` — \(finding.title)\n"
            }
            out += "\n"
        }

        for severity in [AuditSeverity.critical, .high, .medium, .low] {
            let items = report.grouped.filter { $0.severity == severity }
            guard !items.isEmpty else { continue }
            out += "## \(severity.label)\n\n"
            for finding in items {
                out += "- `\(location(finding))` — **\(finding.title)** (`\(finding.ruleID)`)\n"
                out += "  - Why: \(finding.detail)\n"
                out += "  - Fix: \(finding.fix)\n"
            }
            out += "\n"
        }
        return out
    }

    public static func githubAnnotations(_ report: AuditReport) -> [String] {
        report.grouped.map { finding in
            let level = finding.severity >= .high ? "error" : "warning"
            let lineParam = finding.line.map { ",line=\($0)" } ?? ""
            return "::\(level) file=\(finding.file)\(lineParam),title=\(finding.title)::\(finding.detail)"
        }
    }

    private static func location(_ finding: AuditFinding) -> String {
        finding.line.map { "\(finding.file):\($0)" } ?? finding.file
    }
}
