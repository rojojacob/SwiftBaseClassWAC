import ArgumentParser

@main
struct Gate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gate",
        abstract: "Scope-aware quality gate for the WAC iOS standard.",
        subcommands: [All.self, ScreenCommand.self, ScreensCommand.self, BranchCommand.self],
        defaultSubcommand: All.self
    )
}
