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
            // Without any -only-testing target this would degrade to a bare `xcodebuild
            // test` — the WHOLE suite — silently defeating the scope (e.g. a mistyped
            // screen name). Fail loudly instead of running everything.
            guard argv.contains(where: { $0.hasPrefix("-only-testing:") }) else {
                let names = scope.screens.map(\.name).joined(separator: ", ")
                let summary = "no tests matched scope (screens: \(names)); check the name"
                    + " and that <Name>*Tests classes exist"
                return StageResult(stage: .test, outcome: .failed, findings: [], summary: summary)
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
