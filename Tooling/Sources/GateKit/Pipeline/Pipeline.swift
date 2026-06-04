public enum PipelineError: Error, Equatable {
    case unknownStage(String)
    case noStages
}

public struct Pipeline {
    public let stages: [any Stage]

    public init(stages: [any Stage]) {
        self.stages = stages
    }

    // Fail-fast: stop at the first stage that does not pass.
    public func run(scope: ResolvedScope, context: GateContext) throws -> Report {
        var results: [StageResult] = []
        for stage in stages {
            let result = try stage.run(scope, context)
            results.append(result)
            if !result.passed { break }
        }
        return Report(results: results)
    }
}

public extension Pipeline {
    static func standard(for config: GateConfig) throws -> Pipeline {
        var stages: [any Stage] = []
        for name in config.stages {
            switch name {
            case "format": stages.append(FormatStage())
            case "lint": stages.append(LintStage())
            case "test": stages.append(BuildTestStage())
            case "build": continue // building is performed by the test stage
            // An unrecognized stage name is almost always a typo in gate.yml. Reject it
            // rather than silently skipping a check the author believed was running.
            default: throw PipelineError.unknownStage(name)
            }
        }
        // An empty pipeline would "pass" having checked nothing — a misleading green.
        guard !stages.isEmpty else { throw PipelineError.noStages }
        return Pipeline(stages: stages)
    }
}
