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
        reader: FakeFileReader(),
        stampStore: FakeStampStore(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.all)

    // format + lint pass (default exit 0), test fails → fail-fast stops there.
    #expect(report.passed == false)
    #expect(report.results.map(\.stage) == [.format, .lint, .test])
}

@Test func passingRunStampsTheScopedScreens() throws {
    let runner = FakeCommandRunner() // all stages exit 0 by default
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Counter"] = ["/repo/App/App/Features/Counter/CounterView.swift"]
    finder.filesByDirectory["/repo/App/AppTests"] = ["/repo/App/AppTests/CounterModelTests.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Counter/CounterView.swift"] = Data("v1".utf8)
    reader.filesByPath["/repo/App/AppTests/CounterModelTests.swift"] = Data("test".utf8)
    let store = FakeStampStore()
    let gate = GateRunner(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        reader: reader,
        stampStore: store,
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.screens(["Counter"]))
    #expect(report.passed)
    #expect(store.load().hashes["Counter"]?.isEmpty == false) // stamped
}

@Test func unitOnlyPassingRunDoesNotStamp() throws {
    let runner = FakeCommandRunner() // all stages exit 0
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Counter"] = ["/repo/App/App/Features/Counter/CounterView.swift"]
    finder.filesByDirectory["/repo/App/AppTests"] = ["/repo/App/AppTests/CounterModelTests.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Counter/CounterView.swift"] = Data("v1".utf8)
    reader.filesByPath["/repo/App/AppTests/CounterModelTests.swift"] = Data("test".utf8)
    let store = FakeStampStore()
    let gate = GateRunner(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        reader: reader,
        stampStore: store,
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.screens(["Counter"]), unitOnly: true)
    #expect(report.passed)
    #expect(store.saved.isEmpty) // unit-only pass must NOT stamp (UI tests were skipped)
}

@Test func failingRunDoesNotStamp() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "fail"))
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Counter"] = ["/repo/App/App/Features/Counter/CounterView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Counter/CounterView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let gate = GateRunner(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        reader: reader,
        stampStore: store,
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.screens(["Counter"]))
    #expect(report.passed == false)
    #expect(store.saved.isEmpty) // never stamped on failure
}

@Test func stagedWithNothingToGateIsAPassingNoOp() throws {
    let runner = FakeCommandRunner()
    // Only a non-feature file staged → resolveStaged returns zero screens.
    runner.stub(whenContains: "--cached", result: ProcessResult(exitCode: 0, stdout: "README.md\n", stderr: ""))
    let gate = GateRunner(
        config: makeTestConfig(),
        runner: runner,
        finder: FakeFileFinder(),
        reader: FakeFileReader(),
        stampStore: FakeStampStore(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.staged)

    #expect(report.passed) // does not block the commit
    #expect(report.results.isEmpty) // pipeline never ran
    #expect(runner.calls.contains { $0.contains("xcodebuild") } == false) // never shelled out
}
