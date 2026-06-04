import Foundation

public struct GateContext {
    public let config: GateConfig
    public let runner: CommandRunner
    public let repoRoot: URL

    public init(config: GateConfig, runner: CommandRunner, repoRoot: URL) {
        self.config = config
        self.runner = runner
        self.repoRoot = repoRoot
    }
}
