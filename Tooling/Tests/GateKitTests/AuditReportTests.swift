import Testing
@testable import GateKit

private func finding(_ sev: AuditSeverity, _ rule: String, line: Int) -> AuditFinding {
    AuditFinding(
        severity: sev,
        file: "App/\(rule).swift",
        line: line,
        ruleID: rule,
        title: rule,
        detail: "because",
        fix: "do this"
    )
}

@Test func healthScoreSubtractsWeightedPenaltiesFlooredAtZero() {
    let report = AuditReport(findings: [
        finding(.critical, "force_try", line: 1), // -15
        finding(.medium, "todo", line: 2), // -3
        finding(.low, "fmt", line: 3) // -1
    ])
    #expect(report.healthScore == 81) // 100 - 19
}

@Test func emptyReportIsPerfectHealth() {
    #expect(AuditReport(findings: []).healthScore == 100)
}

@Test func healthScoreNeverNegative() {
    let many = (0 ..< 20).map { finding(.critical, "r\($0)", line: $0) }
    #expect(AuditReport(findings: many).healthScore == 0)
}

@Test func groupedSortsBySeverityThenFileLine() {
    let report = AuditReport(findings: [
        finding(.low, "a", line: 5), finding(.critical, "b", line: 2), finding(.critical, "a", line: 9)
    ])
    let order = report.grouped.map(\.severity)
    #expect(order == [.critical, .critical, .low])
    // within a severity, sorted by file then line
    #expect(report.grouped[0].ruleID == "a") // App/a.swift < App/b.swift
}

@Test func topNTakesHighestSeverityFirst() {
    let report = AuditReport(findings: [
        finding(.low, "a", line: 1), finding(.critical, "b", line: 1), finding(.high, "c", line: 1)
    ])
    #expect(report.topN(2).map(\.severity) == [.critical, .high])
}

@Test func groupedSortsSameFileByLineAscending() {
    // Same rule → same file ("App/Same.swift"); the within-file tie-break is line asc.
    let report = AuditReport(findings: [
        finding(.high, "Same", line: 30), finding(.high, "Same", line: 5)
    ])
    #expect(report.grouped.map(\.line) == [5, 30])
}

@Test func topNWithNonPositiveCountIsEmpty() {
    let report = AuditReport(findings: [finding(.critical, "a", line: 1)])
    #expect(report.topN(0).isEmpty)
    #expect(report.topN(-3).isEmpty)
}
