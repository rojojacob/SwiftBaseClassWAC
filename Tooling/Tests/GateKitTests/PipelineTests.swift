import Foundation
import Testing
@testable import GateKit

/// A stage that records that it ran and returns a fixed outcome.
private final class SpyStage: Stage {
    let id: StageID
    let outcome: Outcome
    private(set) var didRun = false
    init(id: StageID, outcome: Outcome) {
        self.id = id
        self.outcome = outcome
    }

    func run(_: ResolvedScope, _: GateContext) throws -> StageResult {
        didRun = true
        return StageResult(stage: id, outcome: outcome, findings: [], summary: "\(id.rawValue):\(outcome)")
    }
}

private func anyContext() -> GateContext {
    makeContext(runner: FakeCommandRunner())
}

@Test func pipelineRunsAllStagesWhenGreen() throws {
    let s1 = SpyStage(id: .format, outcome: .passed)
    let s2 = SpyStage(id: .lint, outcome: .passed)
    let report = try Pipeline(stages: [s1, s2]).run(
        scope: ResolvedScope(kind: .all, screens: []), context: anyContext()
    )
    #expect(report.passed)
    #expect(s1.didRun)
    #expect(s2.didRun)
    #expect(report.results.count == 2)
}

@Test func pipelineStopsAtFirstFailure() throws {
    let s1 = SpyStage(id: .format, outcome: .failed)
    let s2 = SpyStage(id: .lint, outcome: .passed)
    let report = try Pipeline(stages: [s1, s2]).run(
        scope: ResolvedScope(kind: .all, screens: []), context: anyContext()
    )
    #expect(report.passed == false)
    #expect(s1.didRun)
    #expect(s2.didRun == false) // fail-fast: never reached
    #expect(report.results.count == 1)
}

@Test func standardFactoryMapsConfigStages() throws {
    // makeTestConfig() has stages [format, lint, build, test]; `build` folds into the test stage.
    let pipeline = try Pipeline.standard(for: makeTestConfig())
    #expect(pipeline.stages.map(\.id) == [.format, .lint, .test])
}

@Test func standardFactoryRejectsUnknownStage() {
    // A typo'd stage name must not be silently dropped — it would skip a real check.
    #expect(throws: PipelineError.unknownStage("lnt")) {
        _ = try Pipeline.standard(for: makeTestConfig(stages: "[format, lnt, test]"))
    }
}

@Test func standardFactoryRejectsEmptyPipeline() {
    // `build` folds into test and adds no stage of its own, so [build] yields nothing.
    #expect(throws: PipelineError.noStages) {
        _ = try Pipeline.standard(for: makeTestConfig(stages: "[build]"))
    }
}

@Test func standardFactoryRejectsKeywordStages() {
    // archive/testflight are CLI keyword stages, never part of the default pipeline.
    #expect(throws: PipelineError.keywordStage("archive")) {
        _ = try Pipeline.standard(for: makeTestConfig(stages: "[format, archive]"))
    }
}
