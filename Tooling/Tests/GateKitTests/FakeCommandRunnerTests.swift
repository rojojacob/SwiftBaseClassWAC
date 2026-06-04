import Foundation
import Testing
@testable import GateKit

@Test func fakeRecordsCallsAndMatchesStubs() throws {
    let fake = FakeCommandRunner()
    fake.stub(whenContains: "swiftlint", result: ProcessResult(exitCode: 2, stdout: "boom", stderr: ""))

    let lint = try fake.run(["swiftlint", "lint"], cwd: URL(fileURLWithPath: "/"))
    let other = try fake.run(["git", "status"], cwd: URL(fileURLWithPath: "/"))

    #expect(lint.exitCode == 2)
    #expect(lint.succeeded == false)
    #expect(other.succeeded == true) // default result
    #expect(fake.calls.count == 2)
    #expect(fake.calls.first == ["swiftlint", "lint"])
}
