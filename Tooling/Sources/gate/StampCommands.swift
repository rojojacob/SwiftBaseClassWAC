import ArgumentParser
import Foundation
import GateKit

struct VerifyStampCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify-stamp",
        abstract: "Fail if any screen changed since its last green gate (Xcode build-phase guard)."
    )
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let skip = ProcessInfo.processInfo.environment["GATE_SKIP_STAMP"] == "1"
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let result = try gate.verifyStamp(skip: skip)
        if result.skipped {
            print("gate verify-stamp skipped (GATE_SKIP_STAMP=1)")
            return
        }
        if result.passed {
            print("gate stamp current")
            return
        }
        for name in result.staleScreens {
            print("\(name) changed since last green gate — run 'gate screen \(name)'")
        }
        throw ExitCode.failure
    }
}
