import Testing
@testable import GateKit

@Test func stageResultReportsPassFromOutcome() {
    let pass = StageResult(stage: .lint, outcome: .passed, findings: [], summary: "clean")
    let fail = StageResult(stage: .lint, outcome: .failed, findings: [], summary: "2 violations")
    #expect(pass.passed)
    #expect(fail.passed == false)
}
