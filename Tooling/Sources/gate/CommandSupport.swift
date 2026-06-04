import ArgumentParser
import Foundation
import GateKit

enum CommandSupport {
    static func execute(
        common: CommonOptions,
        scope rawScope: ScopeKind,
        unitOnly: Bool = false,
        archive: Bool = false,
        testflight: Bool = false
    ) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let scope = applyDefaults(rawScope, config: gate.config)
        let report = try gate.run(scope, unitOnly: unitOnly)
        printReport(report)
        if !report.passed { throw ExitCode.failure }

        // Keyword release stages only run AFTER a green gate, and only when requested.
        // A vacuous pass (e.g. `gate staged` with nothing screen-relevant staged →
        // zero results) must NOT certify a release — there is nothing to archive/upload.
        guard archive || testflight, !report.results.isEmpty else { return }
        let context = GateContext(config: gate.config, runner: SystemCommandRunner(), repoRoot: cwd)
        if archive { try runRelease(ArchiveStage(), context) }
        if testflight { try runRelease(TestFlightStage(), context) }
    }

    private static func runRelease(_ stage: any Stage, _ context: GateContext) throws {
        let result = try stage.run(ResolvedScope(kind: .all, screens: []), context)
        print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
        if !result.passed { throw ExitCode.failure }
    }

    static func applyDefaults(_ scope: ScopeKind, config: GateConfig) -> ScopeKind {
        if case let .branch(base) = scope, base.isEmpty {
            return .branch(base: config.baseBranch)
        }
        return scope
    }

    static func printReport(_ report: Report) {
        for result in report.results {
            print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
        }
        print(report.passed ? "\n✔ gate passed" : "\n✘ gate failed")
    }
}
