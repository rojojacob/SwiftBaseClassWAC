import ArgumentParser
import GateKit

struct All: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "all",
        abstract: "Gate the whole repository."
    )
    @OptionGroup var common: CommonOptions
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false

    func run() throws {
        try CommandSupport.execute(common: common, scope: .all, archive: archive, testflight: testflight)
    }
}

struct ScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screen",
        abstract: "Gate a single screen (feature folder)."
    )
    @Argument(help: "Screen name, e.g. Posts.") var name: String
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(
            common: common,
            scope: .screens([name]),
            unitOnly: noUI,
            archive: archive,
            testflight: testflight
        )
    }
}

struct ScreensCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screens",
        abstract: "Gate several screens."
    )
    @Argument(help: "Screen names.") var names: [String]
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(
            common: common,
            scope: .screens(names),
            unitOnly: noUI,
            archive: archive,
            testflight: testflight
        )
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
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(
            common: common,
            scope: .branch(base: base),
            unitOnly: noUI,
            archive: archive,
            testflight: testflight
        )
    }
}

struct StagedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "staged",
        abstract: "Gate the screens with staged changes (pre-commit)."
    )
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        try CommandSupport.execute(
            common: common,
            scope: .staged,
            unitOnly: noUI,
            archive: archive,
            testflight: testflight
        )
    }
}
