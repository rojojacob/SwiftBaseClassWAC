import ArgumentParser
import Foundation
import GateKit

struct FormatCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "format",
        abstract: "Check (or fix) formatting."
    )
    @Flag(name: .long, help: "Rewrite files in place instead of just checking.") var fix = false

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let argv = fix ? ["swiftformat", "."] : ["swiftformat", "--lint", "."]
        let result = try SystemCommandRunner().run(argv, cwd: cwd)
        // swiftformat writes its diagnostics to stderr, so surface both streams.
        let output = result.stdout + result.stderr
        if !output.isEmpty { print(output) }
        if !result.succeeded { throw ExitCode.failure }
    }
}

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Run swiftlint (strict)."
    )
    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = try SystemCommandRunner().run(["swiftlint", "lint", "--strict", "--quiet"], cwd: cwd)
        let output = result.stdout + result.stderr
        if !output.isEmpty { print(output) }
        if !result.succeeded { throw ExitCode.failure }
    }
}
