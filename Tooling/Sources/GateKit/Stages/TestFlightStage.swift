/// Keyword stage: delegates a signed build + TestFlight upload to the project's
/// fastlane lane (default `beta`). Never automatic — run via `gate testflight` or
/// `--testflight`. The gate does not manage signing; fastlane (match) does.
public struct TestFlightStage: Stage {
    public let id: StageID = .testflight
    public init() {}

    public func run(_: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let lane = context.config.release?.testflightLane ?? "beta"
        let result = try context.runner.run(["bundle", "exec", "fastlane", lane], cwd: context.repoRoot)
        return StageResult(
            stage: .testflight,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded
                ? "uploaded to TestFlight via fastlane \(lane)"
                : "testflight failed:\n\(result.stdout)\(result.stderr)"
        )
    }
}
