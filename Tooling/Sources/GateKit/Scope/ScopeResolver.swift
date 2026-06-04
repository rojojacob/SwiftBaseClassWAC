import Foundation

public enum ScopeError: Error {
    case gitFailed(String)
}

public struct ScopeResolver {
    private let config: GateConfig
    private let runner: CommandRunner
    private let finder: FileFinder
    private let repoRoot: URL

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
        case .staged:
            return try resolveStaged()
        }
    }

    private func resolveBranch(base: String) throws -> ResolvedScope {
        let result = try runner.run(["git", "diff", "--name-only", "\(base)...HEAD"], cwd: repoRoot)
        guard result.succeeded else {
            throw ScopeError.gitFailed("git diff \(base)...HEAD failed: \(result.stderr)")
        }
        let changed = result.stdout.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        if let escalated = sharedOrRootEscalation(changed) { return escalated }
        let names = owningScreenNames(changed)
        guard !names.isEmpty else { return ResolvedScope(kind: .all, screens: []) }
        return ResolvedScope(kind: .screens, screens: names.sorted().map(screen(named:)))
    }

    private func resolveStaged() throws -> ResolvedScope {
        let result = try runner.run(["git", "diff", "--cached", "--name-only"], cwd: repoRoot)
        guard result.succeeded else {
            throw ScopeError.gitFailed("git diff --cached failed: \(result.stderr)")
        }
        let changed = result.stdout.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        // Unlike branch, an empty staged set means "nothing to gate" (not "run all").
        if changed.isEmpty { return ResolvedScope(kind: .screens, screens: []) }
        if let escalated = sharedOrRootEscalation(changed) { return escalated }
        let names = owningScreenNames(changed)
        return ResolvedScope(kind: .screens, screens: names.sorted().map(screen(named:)))
    }

    /// Shared-dir or features-root change → run everything (returns `.all`), else nil.
    private func sharedOrRootEscalation(_ changed: [String]) -> ResolvedScope? {
        let sharedDirs = Set(config.conventions.sharedDirs)
        for file in changed where file.split(separator: "/").contains(where: { sharedDirs.contains(String($0)) }) {
            return ResolvedScope(kind: .all, screens: [])
        }
        let prefix = config.conventions.featuresDir + "/"
        for file in changed where file.hasPrefix(prefix) {
            let rest = file.dropFirst(prefix.count)
            if !rest.contains("/"), file.hasSuffix(".swift") {
                return ResolvedScope(kind: .all, screens: [])
            }
        }
        return nil
    }

    private func owningScreenNames(_ changed: [String]) -> Set<String> {
        let prefix = config.conventions.featuresDir + "/"
        var names = Set<String>()
        for file in changed where file.hasPrefix(prefix) {
            let rest = file.dropFirst(prefix.count)
            if let slash = rest.firstIndex(of: "/") {
                names.insert(String(rest[..<slash]))
            }
        }
        return names
    }

    /// Every screen in the project: one per immediate subdirectory of the features dir.
    public func allScreens() -> [Screen] {
        let featuresDir = repoRoot.appendingPathComponent(config.conventions.featuresDir).path
        return finder.subdirectories(of: featuresDir).map(screen(named:)) // already sorted
    }

    private func screen(named name: String) -> Screen {
        let pattern = config.conventions.testGlob.replacingOccurrences(of: "{Name}", with: name)
        let unitDir = repoRoot.appendingPathComponent(config.conventions.unitDir).path
        let uiDir = repoRoot.appendingPathComponent(config.conventions.uiDir).path
        let unitFiles = finder.files(in: unitDir, matching: pattern)
        let uiFiles = finder.files(in: uiDir, matching: pattern)
        return Screen(
            name: name,
            codePath: "\(config.conventions.featuresDir)/\(name)",
            unitTestClasses: unitFiles.map(Self.className(fromPath:)),
            uiTestClasses: uiFiles.map(Self.className(fromPath:)),
            unitTestFiles: unitFiles,
            uiTestFiles: uiFiles
        )
    }

    private static func className(fromPath path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
