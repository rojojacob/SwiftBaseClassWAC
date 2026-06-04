import ArgumentParser
import GateKit

struct All: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "all",
        abstract: "Gate the whole repository."
    )
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .all)
    }
}

struct ScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screen",
        abstract: "Gate a single screen (feature folder)."
    )
    @Argument(help: "Screen name, e.g. Posts.") var name: String
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .screens([name]), unitOnly: noUI)
    }
}

struct ScreensCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screens",
        abstract: "Gate several screens."
    )
    @Argument(help: "Screen names.") var names: [String]
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .screens(names), unitOnly: noUI)
    }
}

struct BranchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "branch",
        abstract: "Gate only the screens changed on this branch."
    )
    @Option(name: .long, help: "Base branch for the diff (defaults to gate.yml base_branch).")
    var base: String = ""
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .branch(base: base), unitOnly: noUI)
    }
}

struct StagedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "staged",
        abstract: "Gate the screens with staged changes (pre-commit)."
    )
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .staged, unitOnly: noUI)
    }
}
