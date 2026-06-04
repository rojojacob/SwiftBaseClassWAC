import Foundation
import Testing
@testable import GateKit

@Test func auditorAggregatesLintFormatAndNoTestFindings() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "--reporter", result: ProcessResult(
        exitCode: 0,
        stdout: """
        [{"file":"/repo/App/App/Features/Counter/CounterView.swift","line":2,
          "reason":"Force tries should be avoided","rule_id":"force_try",
          "severity":"Error","type":"Force Try"}]
        """,
        stderr: ""
    ))
    // swiftformat --lint writes "needs formatting" paths to stderr:
    runner.stub(whenContains: "swiftformat", result: ProcessResult(
        exitCode: 1,
        stdout: "",
        stderr: "/repo/App/App/Features/Counter/CounterModel.swift:1:1: warning: (indent)\n"
    ))
    let finder = FakeFileFinder()
    finder.subdirsByDirectory["/repo/App/App/Features"] = ["Counter", "Posts"]
    // Counter has a unit test; Posts has none → Posts is a no-tests finding.
    finder.filesByDirectory["/repo/App/AppTests"] = ["/repo/App/AppTests/CounterModelTests.swift"]

    let auditor = Auditor(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let report = try auditor.audit()

    #expect(report.findings.contains { $0.ruleID == "force_try" && $0.severity == .critical })
    #expect(report.findings.contains { $0.ruleID == "swiftformat" && $0.severity == .low })
    #expect(report.findings.contains { $0.ruleID == "no_tests" && $0.file.contains("Posts") && $0.severity == .high })
}

@Test func cleanFormatProducesNoDriftFindings() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "--reporter", result: ProcessResult(exitCode: 0, stdout: "[]", stderr: ""))
    runner.stub(whenContains: "swiftformat", result: ProcessResult(exitCode: 0, stdout: "", stderr: ""))
    let auditor = Auditor(
        config: makeTestConfig(),
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let report = try auditor.audit()
    #expect(report.findings.contains { $0.ruleID == "swiftformat" } == false)
}

@Test func missingToolSurfacesAsHighFindingNotFalseClean() throws {
    let runner = FakeCommandRunner()
    // exit 127 = command not found (e.g. swiftlint not installed)
    runner.stub(whenContains: "--reporter", result: ProcessResult(exitCode: 127, stdout: "", stderr: "not found"))
    runner.stub(whenContains: "swiftformat", result: ProcessResult(exitCode: 0, stdout: "", stderr: ""))
    let auditor = Auditor(
        config: makeTestConfig(),
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let report = try auditor.audit()
    #expect(report.findings.contains { $0.ruleID == "audit_tool" && $0.severity == .high })
}
