import Foundation

/// Scans the repo and aggregates findings from SwiftLint, SwiftFormat drift, and
/// a "screen with no tests" heuristic into an `AuditReport`. All process calls go
/// through `CommandRunner`, so it is unit-tested without real tools.
public struct Auditor {
    private let config: GateConfig
    private let runner: CommandRunner
    private let finder: FileFinder
    private let repoRoot: URL

    public init(config: GateConfig, runner: CommandRunner, finder: FileFinder, repoRoot: URL) {
        self.config = config
        self.runner = runner
        self.finder = finder
        self.repoRoot = repoRoot
    }

    public func audit() throws -> AuditReport {
        var findings: [AuditFinding] = []
        findings += try lintFindings()
        findings += try formatDriftFindings()
        findings += noTestFindings()
        return AuditReport(findings: findings)
    }

    /// A missing tool surfaces as a high-severity finding (lowering the health score)
    /// rather than silently reporting zero violations — a false "clean".
    private func toolMissingFinding(_ tool: String) -> AuditFinding {
        AuditFinding(
            severity: .high,
            file: "(toolchain)",
            line: nil,
            ruleID: "audit_tool",
            title: "\(tool) not installed",
            detail: "The \(tool) scan was skipped because \(tool) is not on PATH.",
            fix: "Install it (e.g. `brew install \(tool)`) and re-run `gate audit`."
        )
    }

    private func lintFindings() throws -> [AuditFinding] {
        let result = try runner.run(["swiftlint", "lint", "--reporter", "json", "--quiet"], cwd: repoRoot)
        if result.exitCode == 127 { return [toolMissingFinding("swiftlint")] } // command not found
        let data = Data(result.stdout.utf8)
        guard !data.isEmpty else { return [] }
        return (try? SwiftLintJSON.findings(fromJSON: data, repoRoot: repoRoot.path)) ?? []
    }

    private func formatDriftFindings() throws -> [AuditFinding] {
        let result = try runner.run(["swiftformat", "--lint", "."], cwd: repoRoot)
        if result.exitCode == 127 { return [toolMissingFinding("swiftformat")] } // command not found
        if result.succeeded { return [] }
        let prefix = repoRoot.path.hasSuffix("/") ? repoRoot.path : repoRoot.path + "/"
        // Each drift line starts with a file path; collect distinct files.
        let files = Set(result.stderr.split(separator: "\n").compactMap { line -> String? in
            guard let path = line.split(separator: ":").first.map(String.init),
                  path.hasSuffix(".swift")
            else {
                return nil
            }
            return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
        })
        return files.sorted().map { file in
            AuditFinding(
                severity: .low,
                file: file,
                line: nil,
                ruleID: "swiftformat",
                title: "Formatting drift",
                detail: "File is not SwiftFormat-clean.",
                fix: "Run `gate format --fix` (or `swiftformat .`)."
            )
        }
    }

    private func noTestFindings() -> [AuditFinding] {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        return resolver.allScreens()
            .filter { $0.unitTestClasses.isEmpty && $0.uiTestClasses.isEmpty }
            .map { screen in
                AuditFinding(
                    severity: .high,
                    file: screen.codePath,
                    line: nil,
                    ruleID: "no_tests",
                    title: "Screen has no tests",
                    detail: "Screen \(screen.name) has no unit or UI tests.",
                    fix: "Add \(screen.name)Tests (unit) and a \(screen.name)UITests flow."
                )
            }
    }
}
