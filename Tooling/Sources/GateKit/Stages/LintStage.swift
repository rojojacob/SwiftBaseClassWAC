public struct LintStage: Stage {
    public let id: StageID = .lint
    public init() {}

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        var argv = ["swiftlint", "lint", "--strict", "--quiet"]
        if scope.kind == .screens {
            argv.append(contentsOf: scope.screens.map(\.codePath))
        }
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .lint,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "lint clean" : "lint violations:\n\(result.stdout)\(result.stderr)"
        )
    }
}
