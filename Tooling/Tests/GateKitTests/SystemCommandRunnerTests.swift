import Foundation
import Testing
@testable import GateKit

@Test func runsRealEchoAndCapturesStdout() throws {
    let runner = SystemCommandRunner()
    let result = try runner.run(["echo", "hello"], cwd: URL(fileURLWithPath: "/tmp"))
    #expect(result.succeeded)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

@Test func nonZeroExitIsReported() throws {
    let runner = SystemCommandRunner()
    let result = try runner.run(["false"], cwd: URL(fileURLWithPath: "/tmp"))
    #expect(result.succeeded == false)
}
