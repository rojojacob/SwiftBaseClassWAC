import Testing
@testable import GateKit

private func sampleReport() -> AuditReport {
    AuditReport(findings: [
        AuditFinding(
            severity: .critical,
            file: "App/AView.swift",
            line: 2,
            ruleID: "force_try",
            title: "Force Try",
            detail: "Force tries should be avoided",
            fix: "use try/catch"
        ),
        AuditFinding(
            severity: .low,
            file: "App/BModel.swift",
            line: nil,
            ruleID: "swiftformat",
            title: "Formatting drift",
            detail: "Not SwiftFormat-clean.",
            fix: "run gate format --fix"
        )
    ])
}

@Test func markdownGroupsBySeverityWithHealthAndTopN() {
    let md = AuditRenderer.markdown(sampleReport(), topN: 5)
    #expect(md.contains("Health: 84/100")) // 100 - 15 - 1
    #expect(md.contains("## Critical"))
    #expect(md.contains("## Low"))
    #expect(md.contains("App/AView.swift:2"))
    #expect(md.contains("force_try"))
    #expect(md.contains("Fix these first")) // top-N section
}

@Test func githubAnnotationsUseErrorForHighPlusAndWarningBelow() {
    let lines = AuditRenderer.githubAnnotations(sampleReport())
    #expect(lines.contains { $0.hasPrefix("::error file=App/AView.swift,line=2") }) // critical → error
    let lowLine = try? #require(lines.first { $0.contains("App/BModel.swift") })
    #expect(lowLine?.hasPrefix("::warning file=App/BModel.swift") == true) // low → warning
    #expect(lowLine?.contains("line=") == false) // nil line → no line= parameter
}

@Test func githubAnnotationsEncodeNewlinesAndCommas() {
    let report = AuditReport(findings: [
        AuditFinding(
            severity: .high,
            file: "App/X.swift",
            line: 1,
            ruleID: "r",
            title: "Has, comma",
            detail: "line1\nline2",
            fix: "f"
        )
    ])
    let line = AuditRenderer.githubAnnotations(report).first ?? ""
    #expect(line.contains("\n") == false) // no raw newline corrupts the annotation
    #expect(line.contains("%0A")) // newline encoded
    #expect(line.contains("title=Has%2C comma")) // comma in title encoded
}
