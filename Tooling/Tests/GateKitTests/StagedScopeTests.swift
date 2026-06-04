import Foundation
import Testing
@testable import GateKit

@Test func stagedMapsCachedDiffToOwningScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(
        whenContains: "--cached",
        result: ProcessResult(
            exitCode: 0,
            stdout: "App/App/Features/Posts/PostsView.swift\n",
            stderr: ""
        )
    )
    let resolver = ScopeResolver(
        config: makeTestConfig(),
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let scope = try resolver.resolve(.staged)
    #expect(scope.kind == .screens)
    #expect(scope.screens.map(\.name) == ["Posts"])
}

@Test func stagedWithNothingStagedReturnsNoScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(
        whenContains: "--cached",
        result: ProcessResult(exitCode: 0, stdout: "", stderr: "")
    )
    let resolver = ScopeResolver(
        config: makeTestConfig(),
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let scope = try resolver.resolve(.staged)
    #expect(scope.kind == .screens)
    #expect(scope.screens.isEmpty)
}
