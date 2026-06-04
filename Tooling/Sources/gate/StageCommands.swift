import ArgumentParser
import Foundation
import GateKit

struct FormatCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "format",
        abstract: "Check (or fix) formatting."
    )
    @Flag(name: .long, help: "Rewrite files in place instead of just checking.") var fix = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let argv = fix ? ["swiftformat", "."] : ["swiftformat", "--lint", "."]
        let result = try SystemCommandRunner().run(argv, cwd: cwd)
        if !result.stdout.isEmpty { print(result.stdout) }
        if !result.succeeded { throw ExitCode.failure }
    }
}

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Run swiftlint (strict)."
    )
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = try SystemCommandRunner().run(["swiftlint", "lint", "--strict", "--quiet"], cwd: cwd)
        if !result.stdout.isEmpty { print(result.stdout) }
        if !result.succeeded { throw ExitCode.failure }
    }
}
