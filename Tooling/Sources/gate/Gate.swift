import ArgumentParser

@main
struct Gate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gate",
        abstract: "Scope-aware quality gate for the WAC iOS standard.",
        subcommands: [
            All.self, ScreenCommand.self, ScreensCommand.self, BranchCommand.self,
            StagedCommand.self, FormatCommand.self, LintCommand.self, VerifyStampCommand.self,
            AuditCommand.self, ArchiveCommand.self, TestFlightCommand.self
        ],
        defaultSubcommand: All.self
    )
}
