public struct BuildTestStage: Stage {
    public let id: StageID = .test
    public init() {}

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let config = context.config
        var argv = [
            "xcodebuild", "test",
            "-project", config.project,
            "-scheme", config.scheme,
            "-destination", "platform=iOS Simulator,name=\(config.simulator)"
        ]
        if scope.kind == .screens {
            for screen in scope.screens {
                for unit in screen.unitTestClasses {
                    argv.append("-only-testing:\(config.targets.unit)/\(unit)")
                }
                for uiClass in screen.uiTestClasses {
                    argv.append("-only-testing:\(config.targets.ui)/\(uiClass)")
                }
            }
        }
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .test,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "tests passed" : "tests failed:\n\(result.stdout)\(result.stderr)"
        )
    }
}
