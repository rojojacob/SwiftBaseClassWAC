import Foundation
import Testing
@testable import GateKit

@Test func lintAllRunsRepoWideStrict() throws {
    let runner = FakeCommandRunner()
    _ = try LintStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("swiftlint"))
    #expect(call.contains("--strict"))
    // No screen paths appended for an `all` run.
    #expect(call.contains { $0.contains("Features/") } == false)
}

@Test func lintScreenScopesToScreenPath() throws {
    let runner = FakeCommandRunner()
    let screen = Screen(name: "Posts", codePath: "App/App/Features/Posts", unitTestClasses: [], uiTestClasses: [])
    _ = try LintStage().run(ResolvedScope(kind: .screens, screens: [screen]), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("App/App/Features/Posts"))
}

@Test func lintFailsOnViolations() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "swiftlint", result: ProcessResult(exitCode: 2, stdout: "", stderr: "violation"))
    let result = try LintStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
}
