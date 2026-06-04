import ArgumentParser
import Foundation
import GateKit

struct AuditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "Scan the repo and emit a prioritized punch-list + health score."
    )
    @Flag(name: .long, help: "Auto-apply the safe fixes (swiftformat + swiftlint --fix).") var fix = false
    @Option(name: .long, help: "Write the Markdown report to this path.") var report = "GATE_REPORT.md"
    @Flag(name: .long, help: "Emit GitHub Actions annotations to stdout.") var annotate = false
    @Flag(name: .long, help: "Exit non-zero if health < thresholds.health_min.") var enforce = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let runner = SystemCommandRunner()

        if fix {
            _ = try? runner.run(["swiftformat", "."], cwd: cwd)
            _ = try? runner.run(["swiftlint", "--fix", "--quiet"], cwd: cwd)
        }

        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let config = try GateConfig.load(from: configURL)
        let auditor = Auditor(
            config: config,
            runner: runner,
            finder: SystemFileFinder(),
            repoRoot: cwd
        )
        let result = try auditor.audit()

        let markdown = AuditRenderer.markdown(result, topN: 10)
        try? markdown.write(toFile: report, atomically: true, encoding: .utf8)

        if annotate {
            for line in AuditRenderer.githubAnnotations(result) {
                print(line)
            }
        }
        print("Audit: health \(result.healthScore)/100, \(result.findings.count) finding(s) → \(report)")

        if enforce, let minimum = config.thresholds?.healthMin, result.healthScore < minimum {
            print("✘ health \(result.healthScore) below required \(minimum)")
            throw ExitCode.failure
        }
    }
}
