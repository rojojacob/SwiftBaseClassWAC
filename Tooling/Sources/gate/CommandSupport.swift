import ArgumentParser
import Foundation
import GateKit

enum CommandSupport {
    static func execute(common: CommonOptions, scope rawScope: ScopeKind) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let scope = applyDefaults(rawScope, config: gate.config)
        let report = try gate.run(scope)
        printReport(report)
        if !report.passed { throw ExitCode.failure }
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
