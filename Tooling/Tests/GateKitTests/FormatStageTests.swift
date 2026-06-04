import Foundation
import Testing
@testable import GateKit

@Test func formatPassesWhenSwiftFormatExitsZero() throws {
    let runner = FakeCommandRunner() // default exit 0
    let result = try FormatStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.stage == .format)
    #expect(result.passed)
    #expect(runner.calls.first?.contains("swiftformat") == true)
    #expect(runner.calls.first?.contains("--lint") == true)
}

@Test func formatFailsWhenSwiftFormatExitsNonZero() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "swiftformat", result: ProcessResult(exitCode: 1, stdout: "", stderr: "needs formatting"))
    let result = try FormatStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
}
