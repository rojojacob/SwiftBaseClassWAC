import Foundation
import Testing
@testable import GateKit

@Test func gateRunnerRunsConfiguredPipelineForScope() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "fail"))
    let gate = GateRunner(
        config: makeTestConfig(), // stages [format, lint, build, test] → pipeline [format, lint, test]
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.all)

    // format + lint pass (default exit 0), test fails → fail-fast stops there.
    #expect(report.passed == false)
    #expect(report.results.map(\.stage) == [.format, .lint, .test])
}
