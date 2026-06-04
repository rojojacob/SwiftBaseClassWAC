import Foundation
import Testing
@testable import GateKit

@Test func archiveRunsUnsignedXcodebuildArchive() throws {
    let runner = FakeCommandRunner()
    let result = try ArchiveStage().run(
        ResolvedScope(kind: .all, screens: []), makeContext(runner: runner)
    )
    let call = try #require(runner.calls.first)
    #expect(call.contains("xcodebuild"))
    #expect(call.contains("archive"))
    #expect(call.contains("-scheme"))
    #expect(call.contains("CODE_SIGNING_ALLOWED=NO")) // unsigned
    #expect(call.contains("GATE_SKIP_STAMP=1")) // don't deadlock on the build-phase guard
    #expect(call.contains { $0.hasPrefix("-archivePath") || $0.hasSuffix(".xcarchive") })
    #expect(result.passed)
}

@Test func archiveFailsAndSurfacesOutput() throws {
    let runner = FakeCommandRunner()
    runner.stub(
        whenContains: "archive",
        result: ProcessResult(exitCode: 65, stdout: "", stderr: "ARCHIVE FAILED")
    )
    let result = try ArchiveStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(result.summary.contains("ARCHIVE FAILED"))
}
