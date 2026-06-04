import Foundation

public struct GateRunner {
    public let config: GateConfig
    private let runner: CommandRunner
    private let finder: FileFinder
    private let repoRoot: URL

    public init(config: GateConfig, runner: CommandRunner, finder: FileFinder, repoRoot: URL) {
        self.config = config
        self.runner = runner
        self.finder = finder
        self.repoRoot = repoRoot
    }

    public func run(_ kind: ScopeKind) throws -> Report {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        let scope = try resolver.resolve(kind)
        let pipeline = Pipeline.standard(for: config)
        let context = GateContext(config: config, runner: runner, repoRoot: repoRoot)
        return try pipeline.run(scope: scope, context: context)
    }
}

public extension GateRunner {
    static func live(configPath: URL, repoRoot: URL) throws -> GateRunner {
        let config = try GateConfig.load(from: configPath)
        return GateRunner(
            config: config,
            runner: SystemCommandRunner(),
            finder: SystemFileFinder(),
            repoRoot: repoRoot
        )
    }
}
