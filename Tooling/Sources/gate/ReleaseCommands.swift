import ArgumentParser
import Foundation
import GateKit

private func runReleaseStage(_ stage: any Stage, config configPath: String) throws {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let configURL = URL(fileURLWithPath: configPath, relativeTo: cwd)
    let config = try GateConfig.load(from: configURL)
    let context = GateContext(config: config, runner: SystemCommandRunner(), repoRoot: cwd)
    let result = try stage.run(ResolvedScope(kind: .all, screens: []), context)
    print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
    if !result.passed { throw ExitCode.failure }
}

struct ArchiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "archive",
        abstract: "Build an unsigned .xcarchive (keyword stage; never automatic)."
    )
    @OptionGroup var common: CommonOptions
    func run() throws {
        try runReleaseStage(ArchiveStage(), config: common.config)
    }
}

struct TestFlightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "testflight",
        abstract: "Signed build + TestFlight upload via the fastlane lane (keyword stage)."
    )
    @OptionGroup var common: CommonOptions
    func run() throws {
        try runReleaseStage(TestFlightStage(), config: common.config)
    }
}
