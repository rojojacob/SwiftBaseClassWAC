import Foundation

public struct GateRunner {
    public let config: GateConfig
    private let runner: CommandRunner
    private let finder: FileFinder
    private let reader: FileReading
    private let stampStore: StampStoring
    private let repoRoot: URL

    public init(
        config: GateConfig,
        runner: CommandRunner,
        finder: FileFinder,
        reader: FileReading,
        stampStore: StampStoring,
        repoRoot: URL
    ) {
        self.config = config
        self.runner = runner
        self.finder = finder
        self.reader = reader
        self.stampStore = stampStore
        self.repoRoot = repoRoot
    }

    public func run(_ kind: ScopeKind) throws -> Report {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        let scope = try resolver.resolve(kind)
        let pipeline = try Pipeline.standard(for: config)
        let context = GateContext(config: config, runner: runner, repoRoot: repoRoot)
        let report = try pipeline.run(scope: scope, context: context)
        if report.passed {
            let stamped = scope.isAll ? resolver.allScreens() : scope.screens
            try StampWriter(hasher: hasher(), store: stampStore).record(stamped)
        }
        return report
    }

    public func verifyStamp(skip: Bool) throws -> VerifyStamp.Result {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        let verifier = VerifyStamp(screens: resolver.allScreens, hasher: hasher(), store: stampStore)
        return try verifier.run(skip: skip)
    }

    private func hasher() -> ScreenHasher {
        ScreenHasher(finder: finder, reader: reader, repoRoot: repoRoot)
    }
}

public extension GateRunner {
    static func live(configPath: URL, repoRoot: URL) throws -> GateRunner {
        let config = try GateConfig.load(from: configPath)
        return GateRunner(
            config: config,
            runner: SystemCommandRunner(),
            finder: SystemFileFinder(),
            reader: SystemFileReader(),
            stampStore: SystemStampStore(repoRoot: repoRoot),
            repoRoot: repoRoot
        )
    }
}
