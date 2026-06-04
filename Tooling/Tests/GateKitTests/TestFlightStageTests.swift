import Foundation
import Testing
@testable import GateKit

@Test func flightDelegatesToFastlaneBetaLane() throws {
    let runner = FakeCommandRunner()
    let result = try TestFlightStage().run(
        ResolvedScope(kind: .all, screens: []), makeContext(runner: runner)
    )
    let call = try #require(runner.calls.first)
    #expect(call == ["bundle", "exec", "fastlane", "beta"]) // default lane
    #expect(result.passed)
}

@Test func flightFailsWhenFastlaneFails() throws {
    let runner = FakeCommandRunner()
    runner.stub(
        whenContains: "fastlane",
        result: ProcessResult(exitCode: 1, stdout: "", stderr: "upload failed")
    )
    let result = try TestFlightStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(result.summary.contains("upload failed"))
}

@Test func flightHonorsCustomLane() throws {
    let runner = FakeCommandRunner()
    let config = makeTestConfig(release: "{ testflight_lane: release_candidate }")
    let context = GateContext(config: config, runner: runner, repoRoot: URL(fileURLWithPath: "/repo"))
    _ = try TestFlightStage().run(ResolvedScope(kind: .all, screens: []), context)
    let call = try #require(runner.calls.first)
    #expect(call == ["bundle", "exec", "fastlane", "release_candidate"]) // config override
}
