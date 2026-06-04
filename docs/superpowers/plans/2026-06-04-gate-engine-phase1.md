# Gate Engine — Phase 1 (Keystone) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `gate` Swift-package CLI that resolves a scope (`all` / `screen` / `screens` / `branch`) and runs a fail-fast `format → lint → build+test` pipeline against the existing app, returning a non-zero exit when any stage fails.

**Architecture:** A `GateKit` library holds all logic behind two mockable seams — `CommandRunner` (process execution) and `FileFinder` (file discovery) — so scope resolution, the pipeline, and reporting are unit-tested without shelling out. A thin ArgumentParser executable (`gate`) wires those into four subcommands. Config lives in `gate.yml` (single source of truth), decoded via Yams.

**Tech Stack:** Swift 5.9+ package, ArgumentParser 1.3, Yams 5.1, Swift Testing (`@Test`/`#expect`), driving `swiftformat` / `swiftlint` / `xcodebuild`.

**Conventions for every task:** Run tests with `swift test --package-path Tooling`. Before each `git commit`, run `swiftformat Tooling` (the repo's pre-commit hook auto-formats and `swiftlint --strict` blocks on staged `*.swift`, so keep code lint-clean). Commit messages follow Conventional Commits (a `commit-msg` hook enforces it).

---

## Task 1: Scaffold the Swift package

**Files:**
- Create: `Tooling/Package.swift`
- Create: `Tooling/Sources/GateKit/GateKit.swift`
- Create: `Tooling/Tests/GateKitTests/SmokeTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gate",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GateKit", targets: ["GateKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "GateKit",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .testTarget(
            name: "GateKitTests",
            dependencies: ["GateKit"]
        ),
    ]
)
```

- [ ] **Step 2: Create an empty (compiling) library file**

`Tooling/Sources/GateKit/GateKit.swift`:

```swift
// GateKit — the scope-aware quality-gate engine for the WAC iOS standard.
```

- [ ] **Step 3: Write the failing smoke test**

`Tooling/Tests/GateKitTests/SmokeTests.swift`:

```swift
import Testing
@testable import GateKit

@Test func exposesVersion() {
    #expect(gateKitVersion == "0.1.0")
}
```

- [ ] **Step 4: Run the test, verify it fails to compile**

Run: `swift test --package-path Tooling`
Expected: FAIL — "cannot find 'gateKitVersion' in scope" (Yams + toolchain resolve first; this proves the package builds).

- [ ] **Step 5: Add the symbol**

Append to `Tooling/Sources/GateKit/GateKit.swift`:

```swift
public let gateKitVersion = "0.1.0"
```

- [ ] **Step 6: Run the test, verify it passes**

Run: `swift test --package-path Tooling`
Expected: PASS — "1 test passed".

- [ ] **Step 7: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): scaffold GateKit Swift package"
```

---

## Task 2: `GateConfig` — gate.yml model + loader

**Files:**
- Create: `Tooling/Sources/GateKit/Config/GateConfig.swift`
- Create: `Tooling/Tests/GateKitTests/GateConfigTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/GateConfigTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

private let sampleYAML = """
project: App/App.xcodeproj
scheme: App
targets:
  app: App
  unit: AppTests
  ui: AppUITests
simulator: "iPhone 16"
base_branch: main
conventions:
  features_dir: App/App/Features
  unit_dir: App/AppTests
  ui_dir: App/AppUITests
  test_glob: "{Name}*Tests.swift"
  shared_dirs: [Core, DesignSystem]
stages: [format, lint, build, test]
"""

@Test func parsesAllFields() throws {
    let config = try GateConfig.parse(sampleYAML)
    #expect(config.scheme == "App")
    #expect(config.targets.unit == "AppTests")
    #expect(config.baseBranch == "main")
    #expect(config.conventions.featuresDir == "App/App/Features")
    #expect(config.conventions.testGlob == "{Name}*Tests.swift")
    #expect(config.conventions.sharedDirs == ["Core", "DesignSystem"])
    #expect(config.stages == ["format", "lint", "build", "test"])
}

@Test func parseFailsOnGarbage() {
    #expect(throws: GateConfigError.self) {
        _ = try GateConfig.parse("not: [valid")
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter GateConfigTests`
Expected: FAIL — "cannot find 'GateConfig' in scope".

- [ ] **Step 3: Implement `GateConfig`**

`Tooling/Sources/GateKit/Config/GateConfig.swift`:

```swift
import Foundation
import Yams

public struct GateConfig: Codable, Equatable, Sendable {
    public struct Targets: Codable, Equatable, Sendable {
        public let app: String
        public let unit: String
        public let ui: String
    }

    public struct Conventions: Codable, Equatable, Sendable {
        public let featuresDir: String
        public let unitDir: String
        public let uiDir: String
        public let testGlob: String
        public let sharedDirs: [String]

        enum CodingKeys: String, CodingKey {
            case featuresDir = "features_dir"
            case unitDir = "unit_dir"
            case uiDir = "ui_dir"
            case testGlob = "test_glob"
            case sharedDirs = "shared_dirs"
        }
    }

    public let project: String
    public let scheme: String
    public let targets: Targets
    public let simulator: String
    public let baseBranch: String
    public let conventions: Conventions
    public let stages: [String]

    enum CodingKeys: String, CodingKey {
        case project, scheme, targets, simulator, conventions, stages
        case baseBranch = "base_branch"
    }
}

public enum GateConfigError: Error, Equatable {
    case fileNotFound(String)
    case parseFailed(String)
}

public extension GateConfig {
    static func parse(_ yaml: String) throws -> GateConfig {
        do {
            return try YAMLDecoder().decode(GateConfig.self, from: yaml)
        } catch {
            throw GateConfigError.parseFailed(String(describing: error))
        }
    }

    static func load(from url: URL) throws -> GateConfig {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw GateConfigError.fileNotFound(url.path)
        }
        return try parse(text)
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter GateConfigTests`
Expected: PASS — "2 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add GateConfig gate.yml loader"
```

---

## Task 3: `CommandRunner` seam + `FakeCommandRunner`

**Files:**
- Create: `Tooling/Sources/GateKit/Shell/CommandRunner.swift`
- Create: `Tooling/Tests/GateKitTests/Support/FakeCommandRunner.swift`
- Create: `Tooling/Tests/GateKitTests/FakeCommandRunnerTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/FakeCommandRunnerTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

@Test func fakeRecordsCallsAndMatchesStubs() throws {
    let fake = FakeCommandRunner()
    fake.stub(whenContains: "swiftlint", result: ProcessResult(exitCode: 2, stdout: "boom", stderr: ""))

    let lint = try fake.run(["swiftlint", "lint"], cwd: URL(fileURLWithPath: "/"))
    let other = try fake.run(["git", "status"], cwd: URL(fileURLWithPath: "/"))

    #expect(lint.exitCode == 2)
    #expect(lint.succeeded == false)
    #expect(other.succeeded == true)        // default result
    #expect(fake.calls.count == 2)
    #expect(fake.calls.first == ["swiftlint", "lint"])
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter FakeCommandRunnerTests`
Expected: FAIL — "cannot find 'FakeCommandRunner' / 'ProcessResult' in scope".

- [ ] **Step 3: Implement the protocol + result type**

`Tooling/Sources/GateKit/Shell/CommandRunner.swift`:

```swift
import Foundation

public struct ProcessResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var succeeded: Bool { exitCode == 0 }
}

public protocol CommandRunner {
    func run(_ argv: [String], cwd: URL, env: [String: String]) throws -> ProcessResult
}

public extension CommandRunner {
    func run(_ argv: [String], cwd: URL) throws -> ProcessResult {
        try run(argv, cwd: cwd, env: ProcessInfo.processInfo.environment)
    }
}
```

- [ ] **Step 4: Implement the fake (test support)**

`Tooling/Tests/GateKitTests/Support/FakeCommandRunner.swift`:

```swift
import Foundation
@testable import GateKit

final class FakeCommandRunner: CommandRunner {
    private struct Stub {
        let needle: String
        let result: ProcessResult
    }

    private(set) var calls: [[String]] = []
    private var stubs: [Stub] = []
    var defaultResult = ProcessResult(exitCode: 0, stdout: "", stderr: "")

    func stub(whenContains needle: String, result: ProcessResult) {
        stubs.append(Stub(needle: needle, result: result))
    }

    func run(_ argv: [String], cwd: URL, env: [String: String]) throws -> ProcessResult {
        calls.append(argv)
        for stub in stubs where argv.contains(where: { $0.contains(stub.needle) }) {
            return stub.result
        }
        return defaultResult
    }
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter FakeCommandRunnerTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add CommandRunner seam and test fake"
```

---

## Task 4: `SystemCommandRunner` (real process execution)

**Files:**
- Create: `Tooling/Sources/GateKit/Shell/SystemCommandRunner.swift`
- Create: `Tooling/Tests/GateKitTests/SystemCommandRunnerTests.swift`

- [ ] **Step 1: Write the failing test (real `echo`)**

`Tooling/Tests/GateKitTests/SystemCommandRunnerTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

@Test func runsRealEchoAndCapturesStdout() throws {
    let runner = SystemCommandRunner()
    let result = try runner.run(["echo", "hello"], cwd: URL(fileURLWithPath: "/tmp"))
    #expect(result.succeeded)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

@Test func nonZeroExitIsReported() throws {
    let runner = SystemCommandRunner()
    let result = try runner.run(["false"], cwd: URL(fileURLWithPath: "/tmp"))
    #expect(result.succeeded == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter SystemCommandRunnerTests`
Expected: FAIL — "cannot find 'SystemCommandRunner' in scope".

- [ ] **Step 3: Implement it (concurrent pipe reads avoid deadlock)**

`Tooling/Sources/GateKit/Shell/SystemCommandRunner.swift`:

```swift
import Foundation

public struct SystemCommandRunner: CommandRunner {
    public init() {}

    public func run(_ argv: [String], cwd: URL, env: [String: String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = argv
        process.currentDirectoryURL = cwd
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        // Read both pipes concurrently so a full stderr buffer can't deadlock
        // a blocked stdout read (and vice versa).
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "gate.command.read", attributes: .concurrent)
        let outBox = DataBox()
        let errBox = DataBox()
        queue.async(group: group) { outBox.value = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errBox.value = errPipe.fileHandleForReading.readDataToEndOfFile() }
        process.waitUntilExit()
        group.wait()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outBox.value, as: UTF8.self),
            stderr: String(decoding: errBox.value, as: UTF8.self)
        )
    }
}

private final class DataBox {
    var value = Data()
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter SystemCommandRunnerTests`
Expected: PASS — "2 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add SystemCommandRunner"
```

---

## Task 5: `FileFinder` seam + `Glob` + fakes

**Files:**
- Create: `Tooling/Sources/GateKit/Shell/Glob.swift`
- Create: `Tooling/Sources/GateKit/Shell/FileFinder.swift`
- Create: `Tooling/Sources/GateKit/Shell/SystemFileFinder.swift`
- Create: `Tooling/Tests/GateKitTests/Support/FakeFileFinder.swift`
- Create: `Tooling/Tests/GateKitTests/GlobTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/GlobTests.swift`:

```swift
import Testing
@testable import GateKit

@Test func singleStarPatternMatchesPrefixAndSuffix() {
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsViewModelTests.swift"))
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsTests.swift"))
    #expect(Glob.matches("Counter*Tests.swift", name: "CounterUITests.swift"))
    #expect(Glob.matches("Posts*Tests.swift", name: "OrdersViewModelTests.swift") == false)
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsView.swift") == false)
}

@Test func noStarRequiresExactMatch() {
    #expect(Glob.matches("Exact.swift", name: "Exact.swift"))
    #expect(Glob.matches("Exact.swift", name: "Other.swift") == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter GlobTests`
Expected: FAIL — "cannot find 'Glob' in scope".

- [ ] **Step 3: Implement `Glob`**

`Tooling/Sources/GateKit/Shell/Glob.swift`:

```swift
// Minimal single-`*` glob matcher (sufficient for the test_glob convention).
// Uses stdlib `split` (no Foundation import needed).
public enum Glob {
    public static func matches(_ pattern: String, name: String) -> Bool {
        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return name == pattern }
        let prefix = parts.first ?? ""
        let suffix = parts.last ?? ""
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return false }
        return name.count >= prefix.count + suffix.count
    }
}
```

- [ ] **Step 4: Implement the `FileFinder` protocol + real + fake**

`Tooling/Sources/GateKit/Shell/FileFinder.swift`:

```swift
// Finds source files under a directory whose basename matches a single-`*` glob.
public protocol FileFinder {
    func files(in directory: String, matching pattern: String) -> [String]
}
```

`Tooling/Sources/GateKit/Shell/SystemFileFinder.swift`:

```swift
import Foundation

public struct SystemFileFinder: FileFinder {
    public init() {}

    public func files(in directory: String, matching pattern: String) -> [String] {
        let base = URL(fileURLWithPath: directory)
        guard let enumerator = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: nil
        ) else { return [] }

        var matches: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if Glob.matches(pattern, name: url.lastPathComponent) {
                matches.append(url.path)
            }
        }
        return matches.sorted()
    }
}
```

`Tooling/Tests/GateKitTests/Support/FakeFileFinder.swift`:

```swift
@testable import GateKit

final class FakeFileFinder: FileFinder {
    // Maps a directory path to the files it should "contain".
    var filesByDirectory: [String: [String]] = [:]

    func files(in directory: String, matching pattern: String) -> [String] {
        (filesByDirectory[directory] ?? []).filter { path in
            let name = path.split(separator: "/").last.map(String.init) ?? path
            return Glob.matches(pattern, name: name)
        }
    }
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter GlobTests`
Expected: PASS — "2 tests passed".

- [ ] **Step 6: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add FileFinder seam and Glob matcher"
```

---

## Task 6: Scope value types (`Screen`, `ScopeKind`, `ResolvedScope`)

**Files:**
- Create: `Tooling/Sources/GateKit/Scope/Screen.swift`
- Create: `Tooling/Sources/GateKit/Scope/ScopeKind.swift`
- Create: `Tooling/Sources/GateKit/Scope/ResolvedScope.swift`
- Create: `Tooling/Tests/GateKitTests/ScopeTypesTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/ScopeTypesTests.swift`:

```swift
import Testing
@testable import GateKit

@Test func screenHoldsConventionDerivedPaths() {
    let screen = Screen(
        name: "Posts",
        codePath: "App/App/Features/Posts",
        unitTestClasses: ["PostsViewModelTests"],
        uiTestClasses: ["PostsUITests"]
    )
    #expect(screen.name == "Posts")
    #expect(screen.unitTestClasses == ["PostsViewModelTests"])
}

@Test func resolvedScopeReportsAll() {
    let scope = ResolvedScope(kind: .all, screens: [])
    #expect(scope.isAll)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter ScopeTypesTests`
Expected: FAIL — "cannot find 'Screen' / 'ResolvedScope' in scope".

- [ ] **Step 3: Implement the types**

`Tooling/Sources/GateKit/Scope/Screen.swift`:

```swift
public struct Screen: Equatable, Hashable, Sendable {
    public let name: String
    public let codePath: String
    public let unitTestClasses: [String]
    public let uiTestClasses: [String]

    public init(name: String, codePath: String, unitTestClasses: [String], uiTestClasses: [String]) {
        self.name = name
        self.codePath = codePath
        self.unitTestClasses = unitTestClasses
        self.uiTestClasses = uiTestClasses
    }
}
```

`Tooling/Sources/GateKit/Scope/ScopeKind.swift`:

```swift
public enum ScopeKind: Equatable, Sendable {
    case all
    case screens([String])
    case branch(base: String)
}
```

`Tooling/Sources/GateKit/Scope/ResolvedScope.swift`:

```swift
public struct ResolvedScope: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case all
        case screens
    }

    public let kind: Kind
    public let screens: [Screen]

    public init(kind: Kind, screens: [Screen]) {
        self.kind = kind
        self.screens = screens
    }

    public var isAll: Bool { kind == .all }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter ScopeTypesTests`
Expected: PASS — "2 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add scope value types"
```

---

## Task 7: `ScopeResolver`

**Files:**
- Create: `Tooling/Tests/GateKitTests/Support/TestSupport.swift`
- Create: `Tooling/Sources/GateKit/Scope/ScopeResolver.swift`
- Create: `Tooling/Tests/GateKitTests/ScopeResolverTests.swift`

- [ ] **Step 1: Create the shared test-config helper (used by every later test)**

`Tooling/Tests/GateKitTests/Support/TestSupport.swift`:

```swift
import Foundation
@testable import GateKit

// Shared test fixtures. `makeContext(runner:)` is appended in Task 8 (after
// GateContext exists). Avoid `try!` here — the pre-commit `swiftlint --strict`
// hook flags `force_try`, so use do/catch + fatalError instead.
func makeTestConfig() -> GateConfig {
    do {
        return try GateConfig.parse("""
        project: App/App.xcodeproj
        scheme: App
        targets: { app: App, unit: AppTests, ui: AppUITests }
        simulator: "iPhone 16"
        base_branch: main
        conventions:
          features_dir: App/App/Features
          unit_dir: App/AppTests
          ui_dir: App/AppUITests
          test_glob: "{Name}*Tests.swift"
          shared_dirs: [Core, DesignSystem]
        stages: [format, lint, build, test]
        """)
    } catch {
        fatalError("invalid test YAML: \(error)")
    }
}
```

- [ ] **Step 2: Write the failing tests**

`Tooling/Tests/GateKitTests/ScopeResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

private func makeResolver(runner: CommandRunner, finder: FileFinder) -> ScopeResolver {
    ScopeResolver(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        repoRoot: URL(fileURLWithPath: "/repo")
    )
}

@Test func resolvesNamedScreenWithDiscoveredTestClasses() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/AppTests"] = [
        "/repo/App/AppTests/Features/PostsViewModelTests.swift",
    ]
    finder.filesByDirectory["/repo/App/AppUITests"] = [
        "/repo/App/AppUITests/PostsUITests.swift",
    ]
    let resolver = makeResolver(runner: FakeCommandRunner(), finder: finder)

    let scope = try resolver.resolve(.screens(["Posts"]))

    #expect(scope.kind == .screens)
    #expect(scope.screens.count == 1)
    #expect(scope.screens[0].codePath == "App/App/Features/Posts")
    #expect(scope.screens[0].unitTestClasses == ["PostsViewModelTests"])
    #expect(scope.screens[0].uiTestClasses == ["PostsUITests"])
}

@Test func branchMapsChangedFilesToOwningScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Features/Posts/PostsView.swift\nApp/App/Features/Counter/CounterView.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    let scope = try resolver.resolve(.branch(base: "main"))

    #expect(scope.kind == .screens)
    #expect(scope.screens.map(\.name) == ["Counter", "Posts"])  // sorted
}

@Test func changeUnderSharedDirEscalatesToAll() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Core/Networking/APIClient.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    let scope = try resolver.resolve(.branch(base: "main"))

    #expect(scope.isAll)
}

@Test func branchWithNoMappableChangesFallsBackToAll() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0, stdout: "README.md\n", stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    #expect(try resolver.resolve(.branch(base: "main")).isAll)
}

@Test func allScopeReturnsAll() throws {
    let resolver = makeResolver(runner: FakeCommandRunner(), finder: FakeFileFinder())
    #expect(try resolver.resolve(.all).isAll)
}
```

- [ ] **Step 3: Run the tests, verify they fail**

Run: `swift test --package-path Tooling --filter ScopeResolverTests`
Expected: FAIL — "cannot find 'ScopeResolver' in scope".

- [ ] **Step 4: Implement `ScopeResolver`**

`Tooling/Sources/GateKit/Scope/ScopeResolver.swift`:

```swift
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
            return ResolvedScope(kind: .all, screens: [])  // changes we can't map → be safe, run all
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
```

- [ ] **Step 5: Run the tests, verify they pass**

Run: `swift test --package-path Tooling --filter ScopeResolverTests`
Expected: PASS — "5 tests passed".

- [ ] **Step 6: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add ScopeResolver (naming convention + git-diff)"
```

---

## Task 8: `Stage` protocol, result types, and `GateContext`

**Files:**
- Create: `Tooling/Sources/GateKit/Stages/Stage.swift`
- Create: `Tooling/Sources/GateKit/Pipeline/GateContext.swift`
- Modify: `Tooling/Tests/GateKitTests/Support/TestSupport.swift`
- Create: `Tooling/Tests/GateKitTests/StageResultTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/StageResultTests.swift`:

```swift
import Testing
@testable import GateKit

@Test func stageResultReportsPassFromOutcome() {
    let pass = StageResult(stage: .lint, outcome: .passed, findings: [], summary: "clean")
    let fail = StageResult(stage: .lint, outcome: .failed, findings: [], summary: "2 violations")
    #expect(pass.passed)
    #expect(fail.passed == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter StageResultTests`
Expected: FAIL — "cannot find 'StageResult' in scope".

- [ ] **Step 3: Implement the protocol and types**

`Tooling/Sources/GateKit/Stages/Stage.swift`:

```swift
import Foundation

public enum StageID: String, Equatable, Sendable {
    case format
    case lint
    case test
}

public enum Outcome: Equatable, Sendable {
    case passed
    case failed
}

public struct Finding: Equatable, Sendable {
    public let file: String?
    public let line: Int?
    public let message: String

    public init(file: String? = nil, line: Int? = nil, message: String) {
        self.file = file
        self.line = line
        self.message = message
    }
}

public struct StageResult: Equatable, Sendable {
    public let stage: StageID
    public let outcome: Outcome
    public let findings: [Finding]
    public let summary: String

    public init(stage: StageID, outcome: Outcome, findings: [Finding], summary: String) {
        self.stage = stage
        self.outcome = outcome
        self.findings = findings
        self.summary = summary
    }

    public var passed: Bool { outcome == .passed }
}

public protocol Stage {
    var id: StageID { get }
    func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult
}
```

`Tooling/Sources/GateKit/Pipeline/GateContext.swift`:

```swift
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
```

- [ ] **Step 4: Append the shared `makeContext` helper to TestSupport.swift**

Append to `Tooling/Tests/GateKitTests/Support/TestSupport.swift`:

```swift
func makeContext(runner: CommandRunner) -> GateContext {
    GateContext(config: makeTestConfig(), runner: runner, repoRoot: URL(fileURLWithPath: "/repo"))
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter StageResultTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add Stage protocol, result types, GateContext"
```

---

## Task 9: `FormatStage`

**Files:**
- Create: `Tooling/Sources/GateKit/Stages/FormatStage.swift`
- Create: `Tooling/Tests/GateKitTests/FormatStageTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/FormatStageTests.swift` (uses `makeContext` from `Support/TestSupport.swift`):

```swift
import Foundation
import Testing
@testable import GateKit

@Test func formatPassesWhenSwiftFormatExitsZero() throws {
    let runner = FakeCommandRunner()  // default exit 0
    let result = try FormatStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.stage == .format)
    #expect(result.passed)
    #expect(runner.calls.first?.contains("swiftformat") == true)
    #expect(runner.calls.first?.contains("--lint") == true)
}

@Test func formatFailsWhenSwiftFormatExitsNonZero() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "swiftformat", result: ProcessResult(exitCode: 1, stdout: "", stderr: "needs formatting"))
    let result = try FormatStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter FormatStageTests`
Expected: FAIL — "cannot find 'FormatStage' in scope".

- [ ] **Step 3: Implement `FormatStage`**

`Tooling/Sources/GateKit/Stages/FormatStage.swift`:

```swift
public struct FormatStage: Stage {
    public let id: StageID = .format
    public init() {}

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let result = try context.runner.run(["swiftformat", "--lint", "."], cwd: context.repoRoot)
        return StageResult(
            stage: .format,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "formatting clean" : "formatting issues — run `swiftformat .`"
        )
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter FormatStageTests`
Expected: PASS — "2 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add FormatStage"
```

---

## Task 10: `LintStage` (scoped to screen paths)

**Files:**
- Create: `Tooling/Sources/GateKit/Stages/LintStage.swift`
- Create: `Tooling/Tests/GateKitTests/LintStageTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/LintStageTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

@Test func lintAllRunsRepoWideStrict() throws {
    let runner = FakeCommandRunner()
    _ = try LintStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("swiftlint"))
    #expect(call.contains("--strict"))
    // No screen paths appended for an `all` run.
    #expect(call.contains { $0.contains("Features/") } == false)
}

@Test func lintScreenScopesToScreenPath() throws {
    let runner = FakeCommandRunner()
    let screen = Screen(name: "Posts", codePath: "App/App/Features/Posts", unitTestClasses: [], uiTestClasses: [])
    _ = try LintStage().run(ResolvedScope(kind: .screens, screens: [screen]), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("App/App/Features/Posts"))
}

@Test func lintFailsOnViolations() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "swiftlint", result: ProcessResult(exitCode: 2, stdout: "", stderr: "violation"))
    let result = try LintStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter LintStageTests`
Expected: FAIL — "cannot find 'LintStage' in scope".

- [ ] **Step 3: Implement `LintStage`**

`Tooling/Sources/GateKit/Stages/LintStage.swift`:

```swift
public struct LintStage: Stage {
    public let id: StageID = .lint
    public init() {}

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        var argv = ["swiftlint", "lint", "--strict", "--quiet"]
        if scope.kind == .screens {
            argv.append(contentsOf: scope.screens.map(\.codePath))
        }
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .lint,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "lint clean" : "lint violations:\n\(result.stdout)\(result.stderr)"
        )
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter LintStageTests`
Expected: PASS — "3 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add LintStage with screen scoping"
```

---

## Task 11: `BuildTestStage` (scoped via `-only-testing`)

**Files:**
- Create: `Tooling/Sources/GateKit/Stages/BuildTestStage.swift`
- Create: `Tooling/Tests/GateKitTests/BuildTestStageTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/BuildTestStageTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

@Test func testAllRunsFullSuite() throws {
    let runner = FakeCommandRunner()
    _ = try BuildTestStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("xcodebuild"))
    #expect(call.contains("test"))
    #expect(call.contains("-scheme"))
    #expect(call.contains { $0.hasPrefix("-only-testing:") } == false)
}

@Test func testScreenScopesWithOnlyTestingPerClass() throws {
    let runner = FakeCommandRunner()
    let screen = Screen(
        name: "Counter",
        codePath: "App/App/Features/Counter",
        unitTestClasses: ["CounterModelTests", "CounterViewModelTests"],
        uiTestClasses: ["CounterUITests"]
    )
    _ = try BuildTestStage().run(ResolvedScope(kind: .screens, screens: [screen]), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("-only-testing:AppTests/CounterModelTests"))
    #expect(call.contains("-only-testing:AppTests/CounterViewModelTests"))
    #expect(call.contains("-only-testing:AppUITests/CounterUITests"))
}

@Test func testFailsWhenXcodebuildFails() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "TEST FAILED"))
    let result = try BuildTestStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter BuildTestStageTests`
Expected: FAIL — "cannot find 'BuildTestStage' in scope".

- [ ] **Step 3: Implement `BuildTestStage`**

`Tooling/Sources/GateKit/Stages/BuildTestStage.swift`:

```swift
public struct BuildTestStage: Stage {
    public let id: StageID = .test
    public init() {}

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let config = context.config
        var argv = [
            "xcodebuild", "test",
            "-project", config.project,
            "-scheme", config.scheme,
            "-destination", "platform=iOS Simulator,name=\(config.simulator)",
        ]
        if scope.kind == .screens {
            for screen in scope.screens {
                for unit in screen.unitTestClasses {
                    argv.append("-only-testing:\(config.targets.unit)/\(unit)")
                }
                for ui in screen.uiTestClasses {
                    argv.append("-only-testing:\(config.targets.ui)/\(ui)")
                }
            }
        }
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .test,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "tests passed" : "tests failed"
        )
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter BuildTestStageTests`
Expected: PASS — "3 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add BuildTestStage with -only-testing scoping"
```

---

## Task 12: `Pipeline` + `Report` + standard factory

**Files:**
- Create: `Tooling/Sources/GateKit/Pipeline/Report.swift`
- Create: `Tooling/Sources/GateKit/Pipeline/Pipeline.swift`
- Create: `Tooling/Tests/GateKitTests/PipelineTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tooling/Tests/GateKitTests/PipelineTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

// A stage that records that it ran and returns a fixed outcome.
private final class SpyStage: Stage {
    let id: StageID
    let outcome: Outcome
    private(set) var didRun = false
    init(id: StageID, outcome: Outcome) {
        self.id = id
        self.outcome = outcome
    }

    func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        didRun = true
        return StageResult(stage: id, outcome: outcome, findings: [], summary: "\(id.rawValue):\(outcome)")
    }
}

private func anyContext() -> GateContext { makeContext(runner: FakeCommandRunner()) }

@Test func pipelineRunsAllStagesWhenGreen() throws {
    let s1 = SpyStage(id: .format, outcome: .passed)
    let s2 = SpyStage(id: .lint, outcome: .passed)
    let report = try Pipeline(stages: [s1, s2]).run(
        scope: ResolvedScope(kind: .all, screens: []), context: anyContext()
    )
    #expect(report.passed)
    #expect(s1.didRun)
    #expect(s2.didRun)
    #expect(report.results.count == 2)
}

@Test func pipelineStopsAtFirstFailure() throws {
    let s1 = SpyStage(id: .format, outcome: .failed)
    let s2 = SpyStage(id: .lint, outcome: .passed)
    let report = try Pipeline(stages: [s1, s2]).run(
        scope: ResolvedScope(kind: .all, screens: []), context: anyContext()
    )
    #expect(report.passed == false)
    #expect(s1.didRun)
    #expect(s2.didRun == false)         // fail-fast: never reached
    #expect(report.results.count == 1)
}

@Test func standardFactoryMapsConfigStages() {
    // makeTestConfig() has stages [format, lint, build, test]; `build` folds into the test stage.
    let pipeline = Pipeline.standard(for: makeTestConfig())
    #expect(pipeline.stages.map(\.id) == [.format, .lint, .test])
}
```

- [ ] **Step 2: Run the tests, verify they fail**

Run: `swift test --package-path Tooling --filter PipelineTests`
Expected: FAIL — "cannot find 'Pipeline' in scope".

- [ ] **Step 3: Implement `Report` and `Pipeline`**

`Tooling/Sources/GateKit/Pipeline/Report.swift`:

```swift
public struct Report: Equatable, Sendable {
    public let results: [StageResult]

    public init(results: [StageResult]) {
        self.results = results
    }

    public var passed: Bool { results.allSatisfy(\.passed) }
}
```

`Tooling/Sources/GateKit/Pipeline/Pipeline.swift`:

```swift
public struct Pipeline {
    public let stages: [Stage]

    public init(stages: [Stage]) {
        self.stages = stages
    }

    // Fail-fast: stop at the first stage that does not pass.
    public func run(scope: ResolvedScope, context: GateContext) throws -> Report {
        var results: [StageResult] = []
        for stage in stages {
            let result = try stage.run(scope, context)
            results.append(result)
            if !result.passed { break }
        }
        return Report(results: results)
    }
}

public extension Pipeline {
    static func standard(for config: GateConfig) -> Pipeline {
        var stages: [Stage] = []
        for name in config.stages {
            switch name {
            case "format": stages.append(FormatStage())
            case "lint": stages.append(LintStage())
            case "test": stages.append(BuildTestStage())
            case "build": continue  // building is performed by the test stage
            default: continue
            }
        }
        return Pipeline(stages: stages)
    }
}
```

- [ ] **Step 4: Run the tests, verify they pass**

Run: `swift test --package-path Tooling --filter PipelineTests`
Expected: PASS — "3 tests passed".

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add fail-fast Pipeline and Report"
```

---

## Task 13: `GateRunner` façade

**Files:**
- Create: `Tooling/Sources/GateKit/GateRunner.swift`
- Create: `Tooling/Tests/GateKitTests/GateRunnerTests.swift`

- [ ] **Step 1: Write the failing test**

`Tooling/Tests/GateKitTests/GateRunnerTests.swift`:

```swift
import Foundation
import Testing
@testable import GateKit

@Test func gateRunnerRunsConfiguredPipelineForScope() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "fail"))
    let gate = GateRunner(
        config: makeTestConfig(),          // stages [format, lint, build, test] → pipeline [format, lint, test]
        runner: runner,
        finder: FakeFileFinder(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.all)

    // format + lint pass (default exit 0), test fails → fail-fast stops there.
    #expect(report.passed == false)
    #expect(report.results.map(\.stage) == [.format, .lint, .test])
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `swift test --package-path Tooling --filter GateRunnerTests`
Expected: FAIL — "cannot find 'GateRunner' in scope".

- [ ] **Step 3: Implement `GateRunner`**

`Tooling/Sources/GateKit/GateRunner.swift`:

```swift
import Foundation

public struct GateRunner {
    public let config: GateConfig
    let runner: CommandRunner
    let finder: FileFinder
    let repoRoot: URL

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
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `swift test --package-path Tooling --filter GateRunnerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add GateRunner facade"
```

---

## Task 14: The `gate` CLI executable

**Files:**
- Modify: `Tooling/Package.swift` (add ArgumentParser dep + `gate` executable target)
- Create: `Tooling/Sources/gate/Gate.swift`
- Create: `Tooling/Sources/gate/CommonOptions.swift`
- Create: `Tooling/Sources/gate/CommandSupport.swift`
- Create: `Tooling/Sources/gate/Commands.swift`

- [ ] **Step 1: Add ArgumentParser + the executable target to `Package.swift`**

Replace the whole file with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gate",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gate", targets: ["gate"]),
        .library(name: "GateKit", targets: ["GateKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "GateKit",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .executableTarget(
            name: "gate",
            dependencies: [
                "GateKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "GateKitTests",
            dependencies: ["GateKit"]
        ),
    ]
)
```

- [ ] **Step 2: Verify the package still resolves/builds**

Run: `swift build --package-path Tooling`
Expected: FAIL — "no such file" / missing `@main` (the `gate` target has no sources yet). This confirms the target is wired; proceed to add sources.

- [ ] **Step 3: Add the shared options**

`Tooling/Sources/gate/CommonOptions.swift`:

```swift
import ArgumentParser

struct CommonOptions: ParsableArguments {
    @Option(name: .long, help: "Path to gate.yml (relative to the working directory).")
    var config: String = "gate.yml"
}
```

- [ ] **Step 4: Add the command support layer**

`Tooling/Sources/gate/CommandSupport.swift`:

```swift
import ArgumentParser
import Foundation
import GateKit

enum CommandSupport {
    static func execute(common: CommonOptions, scope rawScope: ScopeKind) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let scope = applyDefaults(rawScope, config: gate.config)
        let report = try gate.run(scope)
        printReport(report)
        if !report.passed { throw ExitCode.failure }
    }

    static func applyDefaults(_ scope: ScopeKind, config: GateConfig) -> ScopeKind {
        if case let .branch(base) = scope, base.isEmpty {
            return .branch(base: config.baseBranch)
        }
        return scope
    }

    static func printReport(_ report: Report) {
        for result in report.results {
            print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
        }
        print(report.passed ? "\n✔ gate passed" : "\n✘ gate failed")
    }
}
```

- [ ] **Step 5: Add the root command + subcommands**

`Tooling/Sources/gate/Gate.swift`:

```swift
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
```

`Tooling/Sources/gate/Commands.swift`:

```swift
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
```

- [ ] **Step 6: Build and run `--help`**

Run: `swift build --package-path Tooling && swift run --package-path Tooling gate --help`
Expected: PASS — help text lists subcommands `all`, `screen`, `screens`, `branch`.

- [ ] **Step 7: Commit**

```bash
swiftformat Tooling
git add Tooling
git commit -m "feat(gate): add gate CLI (all/screen/screens/branch)"
```

---

## Task 15: Wire `gate.yml` + wrapper script + end-to-end run

**Files:**
- Create: `gate.yml` (repo root)
- Create: `gate` (repo-root wrapper script)
- Modify: `.gitignore` (ignore the Swift build dir)
- Modify: `README.md` (add a short "Gate engine" section)

- [ ] **Step 1: Create `gate.yml` at the repo root**

```yaml
# gate.yml — single source of truth for the gate engine (see docs/superpowers/specs/2026-06-04-wac-ios-standard-design.md)
project: SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj
scheme: SwiftBaseClassWAC
targets:
  app: SwiftBaseClassWAC
  unit: SwiftBaseClassWACTests
  ui: SwiftBaseClassWACUITests
simulator: "iPhone 16"
base_branch: main
conventions:
  features_dir: SwiftBaseClassWAC/SwiftBaseClassWAC/Features
  unit_dir: SwiftBaseClassWAC/SwiftBaseClassWACTests
  ui_dir: SwiftBaseClassWAC/SwiftBaseClassWACUITests
  test_glob: "{Name}*Tests.swift"
  shared_dirs: [Core, DesignSystem]
stages: [format, lint, build, test]
```

- [ ] **Step 2: Create the wrapper script `gate`**

```bash
#!/usr/bin/env bash
# Thin wrapper so callers run `./gate <scope>` instead of the full swift invocation.
# Builds once, then forwards all arguments to the gate CLI.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec swift run --package-path "$DIR/Tooling" gate "$@"
```

Then: `chmod +x gate`

- [ ] **Step 3: Ignore the Swift build directory**

Append to `.gitignore`:

```
# gate engine (SwiftPM build artifacts)
Tooling/.build/
```

- [ ] **Step 4: Verify scope resolution end-to-end against the real repo (no full build)**

Run: `./gate screen Counter --help >/dev/null && echo OK`
Expected: prints `OK` (the wrapper builds the tool and the CLI parses).

- [ ] **Step 5: Run the real scoped gate for the Counter screen**

Run: `./gate screen Counter`
Expected: prints `✔ format:` then `✔ lint:` then a `test:` line. The `xcodebuild` test stage runs only `CounterModelTests`, `CounterViewModelTests`, and `CounterUITests` on the simulator (may take a few minutes). A passing repo ends with `✔ gate passed`.

> If no `iPhone 16` simulator exists locally, set one that does in `gate.yml > simulator` (list with `xcrun simctl list devices available`).

- [ ] **Step 6: Add a README section**

Add under the existing CI/CD section of `README.md`:

```markdown
## Gate engine

The `gate` CLI (Swift package in `Tooling/`) runs the same quality pipeline,
scoped to what you're working on:

```bash
./gate screen Counter      # one screen: lint + that screen's unit & UI tests
./gate screens Counter Posts
./gate branch              # only the screens changed vs. main
./gate all                 # whole repo (format → lint → build → test)
```

Config lives in `gate.yml`. See the design spec in
`docs/superpowers/specs/2026-06-04-wac-ios-standard-design.md`.
```

- [ ] **Step 7: Commit**

```bash
swiftformat Tooling
git add gate.yml gate .gitignore README.md
git commit -m "feat(gate): wire gate.yml, wrapper script, and docs"
```

---

## Definition of done (Phase 1)

- `swift test --package-path Tooling` is green (all GateKit unit tests pass).
- `./gate all`, `./gate screen <Name>`, `./gate screens …`, `./gate branch` all run and return a
  correct non-zero exit when any stage fails.
- Scope resolution maps screens by naming convention and the branch diff, escalating shared-dir
  changes to `all`.
- No logic depends on real disk/process except `SystemCommandRunner` / `SystemFileFinder`, both of
  which sit behind protocols the unit tests fake.

## What Phase 1 deliberately excludes (later phases)

- The verification stamp / `gate verify-stamp` / Xcode build phase, the four hook bindings,
  green-compute skip-on-unchanged + the eco ledger (Phase 2).
- Stronger/architectural lint rules and `gate audit` (Phase 2).
- `gate archive` / `gate testflight` (Phase 3).
- `gate init` / `gate adopt` + bootstrap templates (Phase 4).
- `docs/ARCHITECTURE.md`, `docs/patterns/`, `CLAUDE.md` / `AGENTS.md`, `.claude/commands` (Phase 5).
```
