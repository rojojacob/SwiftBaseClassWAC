public struct FormatStage: Stage {
    public let id: StageID = .format
    public init() {}

    public func run(_: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let result = try context.runner.run(["swiftformat", "--lint", "."], cwd: context.repoRoot)
        return StageResult(
            stage: .format,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "formatting clean" : "formatting issues — run `swiftformat .`"
        )
    }
}
