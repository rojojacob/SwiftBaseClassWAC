/// Keyword stage: builds an UNSIGNED `.xcarchive` (a local release-build check).
/// Never part of the automatic pipeline — run via `gate archive` or `--archive`.
public struct ArchiveStage: Stage {
    public let id: StageID = .archive
    public init() {}

    public func run(_: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let config = context.config
        let archivePath = config.release?.archivePath ?? "build/\(config.scheme).xcarchive"
        let argv = [
            "xcodebuild", "archive",
            "-project", config.project,
            "-scheme", config.scheme,
            "-archivePath", archivePath,
            "-destination", "generic/platform=iOS",
            "CODE_SIGNING_ALLOWED=NO",
            // Skip the in-build verify-stamp guard during the gate's own archive build.
            "GATE_SKIP_STAMP=1"
        ]
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .archive,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded
                ? "archived → \(archivePath)"
                : "archive failed:\n\(result.stdout)\n\(result.stderr)"
        )
    }
}
