import Foundation

public struct ScopeResolver {
    let config: GateConfig
    let runner: CommandRunner
    let finder: FileFinder
    let repoRoot: URL

    public init(config: GateConfig, runner: CommandRunner, finder: FileFinder, repoRoot: URL) {
        self.config = config
        self.runner = runner
        self.finder = finder
        self.repoRoot = repoRoot
    }

    public func resolve(_ kind: ScopeKind) throws -> ResolvedScope {
        switch kind {
        case .all:
            return ResolvedScope(kind: .all, screens: [])
        case let .screens(names):
            return ResolvedScope(kind: .screens, screens: names.sorted().map(screen(named:)))
        case let .branch(base):
            return try resolveBranch(base: base)
        }
    }

    private func resolveBranch(base: String) throws -> ResolvedScope {
        let result = try runner.run(["git", "diff", "--name-only", "\(base)...HEAD"], cwd: repoRoot)
        let changed = result.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }

        // Any change under a shared dir escalates the whole run.
        for file in changed {
            for shared in config.conventions.sharedDirs where file.contains("/\(shared)/") {
                return ResolvedScope(kind: .all, screens: [])
            }
        }

        // Map changed files under the features dir to owning screen names.
        let prefix = config.conventions.featuresDir + "/"
        var names = Set<String>()
        for file in changed where file.hasPrefix(prefix) {
            let rest = file.dropFirst(prefix.count)
            if let slash = rest.firstIndex(of: "/") {
                names.insert(String(rest[..<slash]))
            }
        }

        guard !names.isEmpty else {
            return ResolvedScope(kind: .all, screens: []) // changes we can't map → be safe, run all
        }
        return ResolvedScope(kind: .screens, screens: names.sorted().map(screen(named:)))
    }

    func screen(named name: String) -> Screen {
        let pattern = config.conventions.testGlob.replacingOccurrences(of: "{Name}", with: name)
        let unitDir = repoRoot.appendingPathComponent(config.conventions.unitDir).path
        let uiDir = repoRoot.appendingPathComponent(config.conventions.uiDir).path
        return Screen(
            name: name,
            codePath: "\(config.conventions.featuresDir)/\(name)",
            unitTestClasses: finder.files(in: unitDir, matching: pattern).map(Self.className(fromPath:)),
            uiTestClasses: finder.files(in: uiDir, matching: pattern).map(Self.className(fromPath:))
        )
    }

    static func className(fromPath path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
