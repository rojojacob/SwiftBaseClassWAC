import Foundation
import Testing
@testable import GateKit

@Test func allRunsFullSuite() throws {
    let runner = FakeCommandRunner()
    _ = try BuildTestStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("xcodebuild"))
    #expect(call.contains("test"))
    #expect(call.contains("-scheme"))
    #expect(call.contains { $0.hasPrefix("-only-testing:") } == false)
}

@Test func screenScopesWithOnlyTestingPerClass() throws {
    let runner = FakeCommandRunner()
    let screen = Screen(
        name: "Counter",
        codePath: "App/App/Features/Counter",
        unitTestClasses: ["CounterModelTests", "CounterViewModelTests"],
        uiTestClasses: ["CounterUITests"]
    )
    _ = try BuildTestStage().run(ResolvedScope(kind: .screens, screens: [screen]), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("-only-testing:AppTests/CounterModelTests"))
    #expect(call.contains("-only-testing:AppTests/CounterViewModelTests"))
    #expect(call.contains("-only-testing:AppUITests/CounterUITests"))
}

@Test func failsWhenXcodebuildFails() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "TEST FAILED"))
    let result = try BuildTestStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(result.summary.contains("TEST FAILED"))
}

@Test func screenWithNoMatchingTestsFailsInsteadOfRunningEverything() throws {
    let runner = FakeCommandRunner()
    let ghost = Screen(name: "Ghost", codePath: "App/App/Features/Ghost", unitTestClasses: [], uiTestClasses: [])
    let result = try BuildTestStage().run(ResolvedScope(kind: .screens, screens: [ghost]), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(runner.calls.isEmpty) // never shelled out to a bare, full-suite xcodebuild
    #expect(result.summary.contains("no tests matched scope"))
}
