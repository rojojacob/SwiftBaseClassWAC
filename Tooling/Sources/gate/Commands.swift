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
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .screens([name]))
    }
}

struct ScreensCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screens",
        abstract: "Gate several screens."
    )
    @Argument(help: "Screen names.") var names: [String]
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .screens(names))
    }
}

struct BranchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "branch",
        abstract: "Gate only the screens changed on this branch."
    )
    @Option(name: .long, help: "Base branch for the diff (defaults to gate.yml base_branch).")
    var base: String = ""
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(common: common, scope: .branch(base: base))
    }
}
