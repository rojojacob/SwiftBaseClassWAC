# Gate Phase 2A — Enforcement & "Stuck Until Green" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the gate *enforce* — a per-screen verification stamp that blocks ⌘R until that screen's tests pass, plus the four bindings (pre-commit, pre-push, Xcode build phase, CI) all calling the one `gate` binary, with the CI enhanced additively (nothing green today goes red).

**Architecture:** A passing `gate` run writes `.gate/last-green.json` = `{ "<Screen>": "<contentHash>" }` (SHA-256 of the screen's source + test files). The Xcode build phase runs `gate verify-stamp` (milliseconds, no recursion) and fails the build on any screen whose current hash ≠ its stamped hash, with `GATE_SKIP_STAMP=1` as an escape hatch. Hashing and stamp storage go through new mockable seams (`FileReading`, `StampStoring`) so all logic is unit-tested without touching the real disk. The three blocking bindings rely on the gate's non-zero exit; the build phase relies on the stamp. CI gains caching + a scoped fast-check job + broader branch triggers, each additive and reversible.

**Tech Stack:** Swift 5.9 / SwiftPM (`Tooling/`), Swift Testing (`@Test`/`#expect`), ArgumentParser, CryptoKit (SHA-256), lefthook, GitHub Actions, Xcode 26 `PBXShellScriptBuildPhase`.

**Conventions (carried from Phase 1 — do not violate):**
- Code must be `swiftlint --strict` clean: no `print` in GateKit (CLI `print` is fine), no force-unwrap, no `try!`/`force_try`, lines ≤120, type names ≥3 chars. `.swiftformat` uses `--commas inline` (NO trailing commas) and `--swiftversion 5.0`.
- Swift Testing, not XCTest. `import Foundation` where `URL`/`Data`/`ProcessInfo` are used.
- SourceKit "No such module" / "Cannot find type" diagnostics are FALSE POSITIVES; `cd Tooling && swift test` / `swift build` is ground truth.
- NEVER `git commit --no-verify`. Every commit message ends with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- New GateKit source files are auto-included (SwiftPM). New app/UITest files are auto-included (Xcode synchronized groups). The `gate` package lives in `Tooling/`.

**Existing engine surface (Phase 1 — assume present):**
- `GateConfig` with `.targets.{app,unit,ui}`, `.conventions.{featuresDir,unitDir,uiDir,testGlob,sharedDirs}`, `.scheme`, `.project`, `.simulator`, `.baseBranch`, `.stages`.
- `protocol CommandRunner` / `ProcessResult`; `protocol FileFinder { func files(in:matching:) -> [String] }` (returns `.swift` paths, supports `*` glob); `enum Glob`.
- `Screen { name; codePath; unitTestClasses; uiTestClasses }`, `ScopeKind { all; screens([String]); branch(base:) }`, `ResolvedScope { kind; screens; isAll }` with nested `enum Kind { all; screens }`.
- `ScopeResolver { resolve(_:) }` with private `screen(named:)`; `enum ScopeError { gitFailed(String) }`.
- `Stage`/`StageID {format,lint,test}`/`Outcome`/`StageResult {stage,outcome,findings,summary,passed}`; `FormatStage`, `LintStage`, `BuildTestStage`.
- `GateContext { config; runner; repoRoot }`; `Report { results; passed }`; `Pipeline { run(scope:context:); static standard(for:) throws }`; `PipelineError`.
- `GateRunner { config; run(_ kind: ScopeKind) -> Report; static live(configPath:repoRoot:) }`.
- CLI: `Sources/gate/{Gate,CommonOptions,CommandSupport,Commands}.swift` (`all`/`screen`/`screens`/`branch`).
- Test support: `FakeCommandRunner` (`stub(whenContains:result:)`, `calls`), `FakeFileFinder` (`filesByDirectory`), `TestSupport.makeTestConfig(stages:)` + `makeContext(runner:)`.

---

## File Structure

**New GateKit source files (`Tooling/Sources/GateKit/`):**
- `Shell/FileReader.swift` — `protocol FileReading { func contents(of:) throws -> Data; func exists(_:) -> Bool }`.
- `Shell/SystemFileReader.swift` — real impl over `Data(contentsOf:)` / `FileManager`.
- `Stamp/ScreenHasher.swift` — `ScreenHasher`: SHA-256 of a screen's source + test file contents.
- `Stamp/Stamp.swift` — `Stamp` value (`[String: String]` screen→hash) + `protocol StampStoring`.
- `Stamp/SystemStampStore.swift` — reads/writes `.gate/last-green.json`.
- `Stamp/StampWriter.swift` — `StampWriter`: given verified screens + hasher + store, update the stamp.
- `Stamp/VerifyStamp.swift` — `VerifyStamp`: compare current vs stamped hashes → `VerifyResult`.

**Modified GateKit source files:**
- `Scope/Screen.swift` — add `unitTestFiles: [String]`, `uiTestFiles: [String]` (paths, for hashing).
- `Scope/ScopeKind.swift` — add `case staged`.
- `Scope/ResolvedScope.swift` — unchanged shape; `.staged` resolves to `.screens`/`.all`.
- `Scope/ScopeResolver.swift` — capture test file paths in `screen(named:)`; add `allScreens()` and `resolveStaged()`.
- `Stages/BuildTestStage.swift` — add `unitOnly` flag (omit UI `-only-testing`).
- `Pipeline/Pipeline.swift` — `standard(for:unitOnly:)` passthrough.
- `GateRunner.swift` — write the stamp after a passing run; add `verifyStamp(skip:)`; `live` wires reader+store.

**New CLI files (`Tooling/Sources/gate/`):**
- `StampCommands.swift` — `VerifyStampCommand`.
- `StageCommands.swift` — `FormatCommand`, `LintCommand`.
- (extend `Commands.swift` / `CommonOptions.swift` for `--no-ui`, `staged`.)

**New test files (`Tooling/Tests/GateKitTests/`):**
- `FileReaderTests.swift`, `ScreenHasherTests.swift`, `StampTests.swift`, `StampWriterTests.swift`, `VerifyStampTests.swift`, `StagedScopeTests.swift`, `UnitOnlyTests.swift` + `Support/FakeFileReader.swift`, `Support/FakeStampStore.swift`.

**Modified config (repo root):**
- `lefthook.yml`, `SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj/project.pbxproj`, `.github/workflows/ci.yml`, `.gitignore`, `gate.yml` (add `structure`/no — not needed here).

---

## Milestone A — Hashing & stamp storage (pure engine)

### Task 1: `FileReading` seam + fake + `SystemFileReader`

**Files:**
- Create: `Tooling/Sources/GateKit/Shell/FileReader.swift`
- Create: `Tooling/Sources/GateKit/Shell/SystemFileReader.swift`
- Create: `Tooling/Tests/GateKitTests/Support/FakeFileReader.swift`
- Create: `Tooling/Tests/GateKitTests/FileReaderTests.swift`

- [ ] **Step 1: Write the protocol**

`FileReader.swift`:
```swift
import Foundation

/// Reads file contents and checks existence. The hashing/stamp layers depend on
/// this protocol so they can be unit-tested without touching the real disk.
public protocol FileReading {
    func contents(of path: String) throws -> Data
    func exists(_ path: String) -> Bool
}
```

- [ ] **Step 2: Write the fake**

`Support/FakeFileReader.swift`:
```swift
import Foundation
@testable import GateKit

final class FakeFileReader: FileReading {
    var filesByPath: [String: Data] = [:]

    func contents(of path: String) throws -> Data {
        guard let data = filesByPath[path] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }

    func exists(_ path: String) -> Bool {
        filesByPath[path] != nil
    }
}
```

- [ ] **Step 3: Write the failing test**

`FileReaderTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func fakeReaderReturnsStoredContentsAndExistence() throws {
    let reader = FakeFileReader()
    reader.filesByPath["/repo/A.swift"] = Data("struct A {}".utf8)
    #expect(reader.exists("/repo/A.swift"))
    #expect(reader.exists("/repo/missing.swift") == false)
    #expect(try reader.contents(of: "/repo/A.swift") == Data("struct A {}".utf8))
}

@Test func fakeReaderThrowsForMissingFile() {
    #expect(throws: (any Error).self) {
        _ = try FakeFileReader().contents(of: "/nope.swift")
    }
}
```

- [ ] **Step 4: Run, expect FAIL (no `FileReading`)**

Run: `cd Tooling && swift test --filter FileReaderTests`
Expected: FAIL to compile / "cannot find 'FileReading'".

- [ ] **Step 5: Write `SystemFileReader`**

`SystemFileReader.swift`:
```swift
import Foundation

/// Real `FileReading` over the local filesystem.
public struct SystemFileReader: FileReading {
    public init() {}

    public func contents(of path: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }

    public func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
```

- [ ] **Step 6: Run, expect PASS**

Run: `cd Tooling && swift test --filter FileReaderTests`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
git add Tooling/Sources/GateKit/Shell/FileReader.swift Tooling/Sources/GateKit/Shell/SystemFileReader.swift Tooling/Tests/GateKitTests/Support/FakeFileReader.swift Tooling/Tests/GateKitTests/FileReaderTests.swift
git commit -m "feat(gate): add FileReading seam for content hashing

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: capture test-file paths on `Screen`

**Files:**
- Modify: `Tooling/Sources/GateKit/Scope/Screen.swift`
- Modify: `Tooling/Sources/GateKit/Scope/ScopeResolver.swift`
- Modify: `Tooling/Tests/GateKitTests/ScopeResolverTests.swift`

Hashing a screen needs the *paths* of its test files, but `Screen` currently stores only class names. Add the paths (the resolver already discovers them).

- [ ] **Step 1: Extend `Screen`**

`Screen.swift` — add two stored properties + init params (keep `Equatable, Hashable, Sendable`):
```swift
public struct Screen: Equatable, Hashable, Sendable {
    public let name: String
    public let codePath: String
    public let unitTestClasses: [String]
    public let uiTestClasses: [String]
    public let unitTestFiles: [String]
    public let uiTestFiles: [String]

    public init(
        name: String,
        codePath: String,
        unitTestClasses: [String],
        uiTestClasses: [String],
        unitTestFiles: [String] = [],
        uiTestFiles: [String] = []
    ) {
        self.name = name
        self.codePath = codePath
        self.unitTestClasses = unitTestClasses
        self.uiTestClasses = uiTestClasses
        self.unitTestFiles = unitTestFiles
        self.uiTestFiles = uiTestFiles
    }
}
```
(The defaults keep every existing `Screen(...)` call in tests compiling unchanged.)

- [ ] **Step 2: Populate paths in `ScopeResolver.screen(named:)`**

`ScopeResolver.swift` — replace the body of `screen(named:)`:
```swift
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
```

- [ ] **Step 3: Assert the paths are captured (extend an existing test)**

`ScopeResolverTests.swift` — add to `resolvesNamedScreenWithDiscoveredTestClasses` after the existing expectations:
```swift
    #expect(scope.screens[0].unitTestFiles == ["/repo/App/AppTests/Features/PostsViewModelTests.swift"])
    #expect(scope.screens[0].uiTestFiles == ["/repo/App/AppUITests/PostsUITests.swift"])
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd Tooling && swift test --filter ScopeResolverTests`
Expected: PASS (paths captured; class-name behavior unchanged).

- [ ] **Step 5: Commit**

```bash
git add Tooling/Sources/GateKit/Scope/Screen.swift Tooling/Sources/GateKit/Scope/ScopeResolver.swift Tooling/Tests/GateKitTests/ScopeResolverTests.swift
git commit -m "feat(gate): record test-file paths on Screen for hashing

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `ScreenHasher` — content hash of a screen

**Files:**
- Create: `Tooling/Sources/GateKit/Stamp/ScreenHasher.swift`
- Create: `Tooling/Tests/GateKitTests/ScreenHasherTests.swift`

The hash covers the screen's source files (every `.swift` under `codePath`) plus its unit + UI test files, so any edit to code OR tests invalidates the stamp.

- [ ] **Step 1: Write the failing test**

`ScreenHasherTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

private func screen(_ name: String, unit: [String], ui: [String]) -> Screen {
    Screen(
        name: name,
        codePath: "App/App/Features/\(name)",
        unitTestClasses: [], uiTestClasses: [],
        unitTestFiles: unit, uiTestFiles: ui
    )
}

@Test func hashIsStableForUnchangedContent() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("struct PostsView {}".utf8)
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("test".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let s = screen("Posts", unit: ["/repo/u/PostsTests.swift"], ui: [])

    let a = try hasher.hash(s)
    let b = try hasher.hash(s)
    #expect(a == b)
    #expect(a.isEmpty == false)
}

@Test func hashChangesWhenAnyFileContentChanges() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let s = screen("Posts", unit: [], ui: [])
    let before = try hasher.hash(s)

    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v2".utf8)
    let after = try hasher.hash(s)
    #expect(before != after)
}

@Test func hashChangesWhenTestFileChanges() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = []
    let reader = FakeFileReader()
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("a".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let s = screen("Posts", unit: ["/repo/u/PostsTests.swift"], ui: [])
    let before = try hasher.hash(s)
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("b".utf8)
    #expect(try hasher.hash(s) != before)
}
```

- [ ] **Step 2: Run, expect FAIL (no `ScreenHasher`)**

Run: `cd Tooling && swift test --filter ScreenHasherTests`
Expected: FAIL — cannot find `ScreenHasher`.

- [ ] **Step 3: Implement `ScreenHasher`**

`ScreenHasher.swift`:
```swift
import CryptoKit
import Foundation

/// Computes a content hash for a screen: every `.swift` under its code path plus
/// its unit and UI test files. Any edit to code or tests changes the hash, which
/// is what the verification stamp compares against.
public struct ScreenHasher {
    private let finder: FileFinder
    private let reader: FileReading
    private let repoRoot: URL

    public init(finder: FileFinder, reader: FileReading, repoRoot: URL) {
        self.finder = finder
        self.reader = reader
        self.repoRoot = repoRoot
    }

    public func hash(_ screen: Screen) throws -> String {
        let codeDir = repoRoot.appendingPathComponent(screen.codePath).path
        let sourceFiles = finder.files(in: codeDir, matching: "*")
        // Sort so the hash is independent of filesystem enumeration order.
        let paths = (sourceFiles + screen.unitTestFiles + screen.uiTestFiles).sorted()

        var hasher = SHA256()
        for path in paths {
            // Mix the path in too, so moving identical content between files still changes the hash.
            hasher.update(data: Data(path.utf8))
            hasher.update(data: try reader.contents(of: path))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd Tooling && swift test --filter ScreenHasherTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Tooling/Sources/GateKit/Stamp/ScreenHasher.swift Tooling/Tests/GateKitTests/ScreenHasherTests.swift
git commit -m "feat(gate): add ScreenHasher (SHA-256 of screen source + tests)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `Stamp` + `StampStoring` + `SystemStampStore`

**Files:**
- Create: `Tooling/Sources/GateKit/Stamp/Stamp.swift`
- Create: `Tooling/Sources/GateKit/Stamp/SystemStampStore.swift`
- Create: `Tooling/Tests/GateKitTests/Support/FakeStampStore.swift`
- Create: `Tooling/Tests/GateKitTests/StampTests.swift`

- [ ] **Step 1: Write the failing test**

`StampTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func stampRoundTripsThroughFakeStore() throws {
    let store = FakeStampStore()
    store.save(Stamp(hashes: ["Posts": "abc", "Counter": "def"]))
    #expect(store.load().hashes["Posts"] == "abc")
    #expect(store.load().hashes["Counter"] == "def")
}

@Test func emptyStampWhenNothingSaved() {
    #expect(FakeStampStore().load().hashes.isEmpty)
}

@Test func mergingUpdatesOnlyTheGivenScreens() {
    var stamp = Stamp(hashes: ["Posts": "old", "Counter": "keep"])
    stamp.merge(["Posts": "new"])
    #expect(stamp.hashes["Posts"] == "new")
    #expect(stamp.hashes["Counter"] == "keep")
}
```

- [ ] **Step 2: Write the fake store**

`Support/FakeStampStore.swift`:
```swift
@testable import GateKit

final class FakeStampStore: StampStoring {
    private(set) var saved: [Stamp] = []
    var current = Stamp(hashes: [:])

    func load() -> Stamp { current }
    func save(_ stamp: Stamp) {
        current = stamp
        saved.append(stamp)
    }
}
```

- [ ] **Step 3: Run, expect FAIL**

Run: `cd Tooling && swift test --filter StampTests`
Expected: FAIL — cannot find `Stamp` / `StampStoring`.

- [ ] **Step 4: Implement `Stamp` + `StampStoring`**

`Stamp.swift`:
```swift
import Foundation

/// The per-screen verification stamp: screen name → content hash of its last
/// green run. Persisted as `.gate/last-green.json`.
public struct Stamp: Codable, Equatable, Sendable {
    public private(set) var hashes: [String: String]

    public init(hashes: [String: String]) {
        self.hashes = hashes
    }

    /// Overwrites the hashes for the given screens, leaving the rest untouched.
    public mutating func merge(_ updates: [String: String]) {
        hashes.merge(updates) { _, new in new }
    }
}

/// Reads/writes the stamp. Mockable so stamp logic is unit-tested off-disk.
public protocol StampStoring {
    func load() -> Stamp
    func save(_ stamp: Stamp)
}
```

- [ ] **Step 5: Implement `SystemStampStore`**

`SystemStampStore.swift`:
```swift
import Foundation

/// Stores the stamp at `<repoRoot>/.gate/last-green.json`. A missing or
/// unreadable file is treated as an empty stamp (first run is never wedged).
public struct SystemStampStore: StampStoring {
    private let url: URL
    private let directory: URL

    public init(repoRoot: URL) {
        directory = repoRoot.appendingPathComponent(".gate", isDirectory: true)
        url = directory.appendingPathComponent("last-green.json")
    }

    public func load() -> Stamp {
        guard let data = try? Data(contentsOf: url),
              let stamp = try? JSONDecoder().decode(Stamp.self, from: data) else {
            return Stamp(hashes: [:])
        }
        return stamp
    }

    public func save(_ stamp: Stamp) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stamp) else { return }
        try? data.write(to: url)
    }
}
```

- [ ] **Step 6: Run, expect PASS**

Run: `cd Tooling && swift test --filter StampTests`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add Tooling/Sources/GateKit/Stamp/Stamp.swift Tooling/Sources/GateKit/Stamp/SystemStampStore.swift Tooling/Tests/GateKitTests/Support/FakeStampStore.swift Tooling/Tests/GateKitTests/StampTests.swift
git commit -m "feat(gate): add Stamp model and StampStoring seam

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone B — Screen enumeration, stamping, verify-stamp

### Task 5: `ScopeResolver.allScreens()` — enumerate every screen

**Files:**
- Modify: `Tooling/Sources/GateKit/Scope/ScopeResolver.swift`
- Modify: `Tooling/Tests/GateKitTests/Support/FakeFileFinder.swift`
- Create: `Tooling/Tests/GateKitTests/AllScreensTests.swift`

`verify-stamp` and `gate all` stamping need the full list of screens. A screen = an immediate subdirectory of `featuresDir`. The current `FileFinder` lists `.swift` files; add a directory-listing capability.

- [ ] **Step 1: Extend `FileFinder` with directory listing**

`Tooling/Sources/GateKit/Shell/FileFinder.swift` — add a method to the protocol:
```swift
public protocol FileFinder {
    /// `.swift` source files under `directory` whose name matches the `*` glob.
    func files(in directory: String, matching pattern: String) -> [String]
    /// Immediate subdirectory names of `directory` (one level, no recursion).
    func subdirectories(of directory: String) -> [String]
}
```
`Tooling/Sources/GateKit/Shell/SystemFileFinder.swift` — implement it:
```swift
    public func subdirectories(of directory: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return entries.filter { name in
            var isDir: ObjCBool = false
            let path = (directory as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }.sorted()
    }
```

- [ ] **Step 2: Extend `FakeFileFinder`**

`Support/FakeFileFinder.swift` — add:
```swift
    var subdirsByDirectory: [String: [String]] = [:]

    func subdirectories(of directory: String) -> [String] {
        (subdirsByDirectory[directory] ?? []).sorted()
    }
```

- [ ] **Step 3: Write the failing test**

`AllScreensTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func allScreensEnumeratesFeatureSubdirectories() throws {
    let finder = FakeFileFinder()
    finder.subdirsByDirectory["/repo/App/App/Features"] = ["Posts", "Counter"]
    let resolver = ScopeResolver(
        config: makeTestConfig(), runner: FakeCommandRunner(),
        finder: finder, repoRoot: URL(fileURLWithPath: "/repo")
    )
    let screens = resolver.allScreens()
    #expect(screens.map(\.name) == ["Counter", "Posts"]) // sorted
    #expect(screens.first?.codePath == "App/App/Features/Counter")
}
```

- [ ] **Step 4: Run, expect FAIL**

Run: `cd Tooling && swift test --filter AllScreensTests`
Expected: FAIL — no `allScreens`.

- [ ] **Step 5: Implement `allScreens()`**

`ScopeResolver.swift` — add (public):
```swift
    /// Every screen in the project: one per immediate subdirectory of the features dir.
    public func allScreens() -> [Screen] {
        let featuresDir = repoRoot.appendingPathComponent(config.conventions.featuresDir).path
        return finder.subdirectories(of: featuresDir).sorted().map(screen(named:))
    }
```

- [ ] **Step 6: Run, expect PASS**

Run: `cd Tooling && swift test --filter AllScreensTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Tooling/Sources/GateKit/Shell/FileFinder.swift Tooling/Sources/GateKit/Shell/SystemFileFinder.swift Tooling/Sources/GateKit/Scope/ScopeResolver.swift Tooling/Tests/GateKitTests/Support/FakeFileFinder.swift Tooling/Tests/GateKitTests/AllScreensTests.swift
git commit -m "feat(gate): enumerate all screens via feature subdirectories

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `StampWriter` — record a green run

**Files:**
- Create: `Tooling/Sources/GateKit/Stamp/StampWriter.swift`
- Create: `Tooling/Tests/GateKitTests/StampWriterTests.swift`

- [ ] **Step 1: Write the failing test**

`StampWriterTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func writerStampsOnlyTheVerifiedScreens() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    store.current = Stamp(hashes: ["Counter": "keep"])
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let writer = StampWriter(hasher: hasher, store: store)

    let posts = Screen(name: "Posts", codePath: "App/App/Features/Posts",
                       unitTestClasses: [], uiTestClasses: [])
    try writer.record([posts])

    let saved = store.load()
    #expect(saved.hashes["Counter"] == "keep")            // untouched screens preserved
    #expect(saved.hashes["Posts"]?.isEmpty == false)      // verified screen stamped
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd Tooling && swift test --filter StampWriterTests`
Expected: FAIL — no `StampWriter`.

- [ ] **Step 3: Implement `StampWriter`**

`StampWriter.swift`:
```swift
import Foundation

/// Updates the stamp for the screens that just passed, preserving the rest.
public struct StampWriter {
    private let hasher: ScreenHasher
    private let store: StampStoring

    public init(hasher: ScreenHasher, store: StampStoring) {
        self.hasher = hasher
        self.store = store
    }

    public func record(_ screens: [Screen]) throws {
        guard !screens.isEmpty else { return }
        var updates: [String: String] = [:]
        for screen in screens {
            updates[screen.name] = try hasher.hash(screen)
        }
        var stamp = store.load()
        stamp.merge(updates)
        store.save(stamp)
    }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd Tooling && swift test --filter StampWriterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Tooling/Sources/GateKit/Stamp/StampWriter.swift Tooling/Tests/GateKitTests/StampWriterTests.swift
git commit -m "feat(gate): add StampWriter to record green screens

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `VerifyStamp` — the build-phase guard logic

**Files:**
- Create: `Tooling/Sources/GateKit/Stamp/VerifyStamp.swift`
- Create: `Tooling/Tests/GateKitTests/VerifyStampTests.swift`

- [ ] **Step 1: Write the failing test**

`VerifyStampTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

private func env(_ finder: FakeFileFinder, _ reader: FakeFileReader, _ store: FakeStampStore) -> VerifyStamp {
    VerifyStamp(
        screens: { [Screen(name: "Posts", codePath: "App/App/Features/Posts",
                           unitTestClasses: [], uiTestClasses: [])] },
        hasher: ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo")),
        store: store
    )
}

@Test func verifyPassesWhenHashMatchesStamp() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let verifier = env(finder, reader, store)
    // Stamp the current content, then verify against it.
    try StampWriter(hasher: verifier.hasher, store: store).record(verifier.screens())

    let result = try verifier.run(skip: false)
    #expect(result.passed)
    #expect(result.staleScreens.isEmpty)
}

@Test func verifyFailsAndNamesStaleScreens() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let verifier = env(finder, reader, store)
    try StampWriter(hasher: verifier.hasher, store: store).record(verifier.screens())

    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("EDITED".utf8)
    let result = try verifier.run(skip: false)
    #expect(result.passed == false)
    #expect(result.staleScreens == ["Posts"])
}

@Test func verifyTreatsNeverStampedScreenAsStale() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let result = try env(finder, reader, FakeStampStore()).run(skip: false)
    #expect(result.passed == false)
    #expect(result.staleScreens == ["Posts"])
}

@Test func skipShortCircuitsToPass() throws {
    let result = try env(FakeFileFinder(), FakeFileReader(), FakeStampStore()).run(skip: true)
    #expect(result.passed)
    #expect(result.skipped)
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd Tooling && swift test --filter VerifyStampTests`
Expected: FAIL — no `VerifyStamp`.

- [ ] **Step 3: Implement `VerifyStamp`**

`VerifyStamp.swift`:
```swift
import Foundation

/// Compares each screen's current content hash to its stamped hash. Any
/// mismatch (or never-stamped screen) is "stale" → the build phase fails.
public struct VerifyStamp {
    public let screens: () -> [Screen]
    public let hasher: ScreenHasher
    private let store: StampStoring

    public init(screens: @escaping () -> [Screen], hasher: ScreenHasher, store: StampStoring) {
        self.screens = screens
        self.hasher = hasher
        self.store = store
    }

    public struct Result: Equatable {
        public let passed: Bool
        public let staleScreens: [String]
        public let skipped: Bool
    }

    public func run(skip: Bool) throws -> Result {
        if skip {
            return Result(passed: true, staleScreens: [], skipped: true)
        }
        let stamp = store.load()
        var stale: [String] = []
        for screen in screens() where try hasher.hash(screen) != stamp.hashes[screen.name] {
            stale.append(screen.name)
        }
        return Result(passed: stale.isEmpty, staleScreens: stale.sorted(), skipped: false)
    }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `cd Tooling && swift test --filter VerifyStampTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Tooling/Sources/GateKit/Stamp/VerifyStamp.swift Tooling/Tests/GateKitTests/VerifyStampTests.swift
git commit -m "feat(gate): add VerifyStamp build-phase guard logic

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: wire stamping + verify into `GateRunner`

**Files:**
- Modify: `Tooling/Sources/GateKit/GateRunner.swift`
- Modify: `Tooling/Tests/GateKitTests/GateRunnerTests.swift`

`GateRunner` gains a `reader` + `stampStore`, writes the stamp after a passing run, and exposes `verifyStamp(skip:)`.

- [ ] **Step 1: Write the failing tests**

`GateRunnerTests.swift` — add:
```swift
@Test func passingRunStampsTheScopedScreens() throws {
    let runner = FakeCommandRunner() // all stages exit 0 by default
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Counter"] = ["/repo/App/App/Features/Counter/CounterView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Counter/CounterView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let gate = GateRunner(
        config: makeTestConfig(), runner: runner, finder: finder,
        reader: reader, stampStore: store, repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.screens(["Counter"]))
    #expect(report.passed)
    #expect(store.load().hashes["Counter"]?.isEmpty == false) // stamped
}

@Test func failingRunDoesNotStamp() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "xcodebuild", result: ProcessResult(exitCode: 65, stdout: "", stderr: "fail"))
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Counter"] = ["/repo/App/App/Features/Counter/CounterView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Counter/CounterView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let gate = GateRunner(
        config: makeTestConfig(), runner: runner, finder: finder,
        reader: reader, stampStore: store, repoRoot: URL(fileURLWithPath: "/repo")
    )

    let report = try gate.run(.screens(["Counter"]))
    #expect(report.passed == false)
    #expect(store.saved.isEmpty) // never stamped on failure
}
```
Update the existing `gateRunnerRunsConfiguredPipelineForScope` to use the new initializer signature:
```swift
    let gate = GateRunner(
        config: makeTestConfig(), runner: runner, finder: FakeFileFinder(),
        reader: FakeFileReader(), stampStore: FakeStampStore(),
        repoRoot: URL(fileURLWithPath: "/repo")
    )
```

- [ ] **Step 2: Run, expect FAIL (signature mismatch)**

Run: `cd Tooling && swift test --filter GateRunnerTests`
Expected: FAIL — `GateRunner.init` has no `reader:`/`stampStore:`.

- [ ] **Step 3: Update `GateRunner`**

`GateRunner.swift` — replace the struct + `live`:
```swift
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
```
> `run(_:)` here takes no `unitOnly` argument — that is added (with a default) in Task 9, so this task stands alone and compiles against the Phase-1 `Pipeline.standard(for:)`.

- [ ] **Step 4: Run, expect PASS**

Run: `cd Tooling && swift test --filter GateRunnerTests`
Expected: PASS (the two new stamping tests + the updated existing test).

- [ ] **Step 5: Commit**

```bash
git add Tooling/Sources/GateKit/GateRunner.swift Tooling/Tests/GateKitTests/GateRunnerTests.swift
git commit -m "feat(gate): stamp green runs and expose verifyStamp on GateRunner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone C — CLI surface for the bindings

### Task 9: `--no-ui` (unit-only) testing

**Files:**
- Modify: `Tooling/Sources/GateKit/Stages/BuildTestStage.swift`
- Modify: `Tooling/Sources/GateKit/Pipeline/Pipeline.swift`
- Modify: `Tooling/Tests/GateKitTests/BuildTestStageTests.swift`
- Modify: `Tooling/Tests/GateKitTests/PipelineTests.swift`

- [ ] **Step 1: Write the failing test**

`BuildTestStageTests.swift` — add:
```swift
@Test func unitOnlyOmitsUITargets() throws {
    let runner = FakeCommandRunner()
    let screen = Screen(
        name: "Counter", codePath: "App/App/Features/Counter",
        unitTestClasses: ["CounterModelTests"], uiTestClasses: ["CounterUITests"]
    )
    _ = try BuildTestStage(unitOnly: true)
        .run(ResolvedScope(kind: .screens, screens: [screen]), makeContext(runner: runner))
    let call = try #require(runner.calls.first)
    #expect(call.contains("-only-testing:AppTests/CounterModelTests"))
    #expect(call.contains("-only-testing:AppUITests/CounterUITests") == false) // UI excluded
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd Tooling && swift test --filter BuildTestStageTests`
Expected: FAIL — `BuildTestStage` has no `unitOnly:` init.

- [ ] **Step 3: Implement the flag**

`BuildTestStage.swift` — add the stored flag + guard the UI loop:
```swift
public struct BuildTestStage: Stage {
    public let id: StageID = .test
    private let unitOnly: Bool
    public init(unitOnly: Bool = false) { self.unitOnly = unitOnly }

    public func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let config = context.config
        var argv = [
            "xcodebuild", "test",
            "-project", config.project,
            "-scheme", config.scheme,
            "-destination", "platform=iOS Simulator,name=\(config.simulator)"
        ]
        if scope.kind == .screens {
            for screen in scope.screens {
                for unit in screen.unitTestClasses {
                    argv.append("-only-testing:\(config.targets.unit)/\(unit)")
                }
                if !unitOnly {
                    for uiClass in screen.uiTestClasses {
                        argv.append("-only-testing:\(config.targets.ui)/\(uiClass)")
                    }
                }
            }
            guard argv.contains(where: { $0.hasPrefix("-only-testing:") }) else {
                let names = scope.screens.map(\.name).joined(separator: ", ")
                let summary = "no tests matched scope (screens: \(names)); check the name"
                    + " and that <Name>*Tests classes exist"
                return StageResult(stage: .test, outcome: .failed, findings: [], summary: summary)
            }
        }
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .test,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded ? "tests passed" : "tests failed:\n\(result.stdout)\(result.stderr)"
        )
    }
}
```

- [ ] **Step 4: Thread `unitOnly` through `Pipeline.standard`**

`Pipeline.swift` — change the factory signature + the `test` case:
```swift
    static func standard(for config: GateConfig, unitOnly: Bool = false) throws -> Pipeline {
        var stages: [any Stage] = []
        for name in config.stages {
            switch name {
            case "format": stages.append(FormatStage())
            case "lint": stages.append(LintStage())
            case "test": stages.append(BuildTestStage(unitOnly: unitOnly))
            case "build": continue
            default: throw PipelineError.unknownStage(name)
            }
        }
        guard !stages.isEmpty else { throw PipelineError.noStages }
        return Pipeline(stages: stages)
    }
```
`PipelineTests.swift` — the existing `standardFactoryMapsConfigStages` call needs no change (default `unitOnly: false`). Add:
```swift
@Test func standardFactoryDefaultsToFullTesting() throws {
    let pipeline = try Pipeline.standard(for: makeTestConfig())
    #expect(pipeline.stages.map(\.id) == [.format, .lint, .test])
}
```

- [ ] **Step 5: Thread `unitOnly` through `GateRunner.run`**

`GateRunner.swift` — add the parameter (defaulted, so Task 8's tests are unaffected) and pass it to the factory:
```swift
    public func run(_ kind: ScopeKind, unitOnly: Bool = false) throws -> Report {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        let scope = try resolver.resolve(kind)
        let pipeline = try Pipeline.standard(for: config, unitOnly: unitOnly)
        let context = GateContext(config: config, runner: runner, repoRoot: repoRoot)
        let report = try pipeline.run(scope: scope, context: context)
        if report.passed {
            let stamped = scope.isAll ? resolver.allScreens() : scope.screens
            try StampWriter(hasher: hasher(), store: stampStore).record(stamped)
        }
        return report
    }
```

- [ ] **Step 6: Run, expect PASS**

Run: `cd Tooling && swift test`
Expected: PASS (full suite green — unit-only scoping, factory passthrough, and `GateRunner.run(_:unitOnly:)` all wired).

- [ ] **Step 7: Commit**

```bash
git add Tooling/Sources/GateKit/Stages/BuildTestStage.swift Tooling/Sources/GateKit/Pipeline/Pipeline.swift Tooling/Sources/GateKit/GateRunner.swift Tooling/Tests/GateKitTests/BuildTestStageTests.swift Tooling/Tests/GateKitTests/PipelineTests.swift
git commit -m "feat(gate): add unit-only (--no-ui) test scoping

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: `.staged` scope — git diff of staged files

**Files:**
- Modify: `Tooling/Sources/GateKit/Scope/ScopeKind.swift`
- Modify: `Tooling/Sources/GateKit/Scope/ScopeResolver.swift`
- Create: `Tooling/Tests/GateKitTests/StagedScopeTests.swift`

Pre-commit must gate only the *staged* screens. `.staged` mirrors `.branch` but uses `git diff --cached --name-only`.

- [ ] **Step 1: Add the case**

`ScopeKind.swift`:
```swift
public enum ScopeKind: Equatable, Sendable {
    case all
    case screens([String])
    case branch(base: String)
    case staged
}
```

- [ ] **Step 2: Write the failing test**

`StagedScopeTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func stagedMapsCachedDiffToOwningScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "--cached", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Features/Posts/PostsView.swift\n",
        stderr: ""
    ))
    let resolver = ScopeResolver(
        config: makeTestConfig(), runner: runner,
        finder: FakeFileFinder(), repoRoot: URL(fileURLWithPath: "/repo")
    )
    let scope = try resolver.resolve(.staged)
    #expect(scope.kind == .screens)
    #expect(scope.screens.map(\.name) == ["Posts"])
}

@Test func stagedWithNothingStagedReturnsNoScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "--cached", result: ProcessResult(exitCode: 0, stdout: "", stderr: ""))
    let resolver = ScopeResolver(
        config: makeTestConfig(), runner: runner,
        finder: FakeFileFinder(), repoRoot: URL(fileURLWithPath: "/repo")
    )
    let scope = try resolver.resolve(.staged)
    #expect(scope.kind == .screens)
    #expect(scope.screens.isEmpty)
}
```

- [ ] **Step 3: Run, expect FAIL**

Run: `cd Tooling && swift test --filter StagedScopeTests`
Expected: FAIL — `.staged` not handled.

- [ ] **Step 4: Implement `resolveStaged()`**

`ScopeResolver.swift` — add `.staged` to the `resolve` switch and a private helper. Reuse the existing file→screen mapping by extracting it. Replace the `resolveBranch` mapping block with a shared `map(changedFiles:)` used by both:
```swift
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
```
Refactor `resolveBranch` to share helpers (extract from its existing body, behavior unchanged):
```swift
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
```

- [ ] **Step 5: Run, expect PASS (incl. existing branch tests unchanged)**

Run: `cd Tooling && swift test --filter ScopeResolverTests && swift test --filter StagedScopeTests`
Expected: PASS — branch behavior identical, staged works.

- [ ] **Step 6: Commit**

```bash
git add Tooling/Sources/GateKit/Scope/ScopeKind.swift Tooling/Sources/GateKit/Scope/ScopeResolver.swift Tooling/Tests/GateKitTests/StagedScopeTests.swift
git commit -m "feat(gate): add staged scope (git diff --cached) for pre-commit

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: CLI commands — `verify-stamp`, `format`, `lint`, `staged`, `--no-ui`

**Files:**
- Create: `Tooling/Sources/gate/StampCommands.swift`
- Create: `Tooling/Sources/gate/StageCommands.swift`
- Modify: `Tooling/Sources/gate/Gate.swift`
- Modify: `Tooling/Sources/gate/Commands.swift`
- Modify: `Tooling/Sources/gate/CommandSupport.swift`

This task is CLI wiring (no new unit tests; verified by `gate --help` + an end-to-end run). Keep the CLI a thin shell over GateKit.

- [ ] **Step 1: Add `--no-ui` to the scope commands + a unit-only path**

`CommandSupport.swift` — extend `execute` to thread `unitOnly`:
```swift
    static func execute(common: CommonOptions, scope rawScope: ScopeKind, unitOnly: Bool = false) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let scope = applyDefaults(rawScope, config: gate.config)
        let report = try gate.run(scope, unitOnly: unitOnly)
        printReport(report)
        if !report.passed { throw ExitCode.failure }
    }
```

`Commands.swift` — add `--no-ui` to `ScreenCommand`, `ScreensCommand`, `BranchCommand` and a new `StagedCommand`:
```swift
struct ScreenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "screen", abstract: "Gate a single screen (feature folder).")
    @Argument(help: "Screen name, e.g. Posts.") var name: String
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions
    func run() throws { try CommandSupport.execute(common: common, scope: .screens([name]), unitOnly: noUI) }
}

struct StagedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "staged", abstract: "Gate the screens with staged changes (pre-commit).")
    @Flag(name: .long, help: "Run unit tests only (skip UI tests).") var noUI = false
    @OptionGroup var common: CommonOptions
    func run() throws { try CommandSupport.execute(common: common, scope: .staged, unitOnly: noUI) }
}
```
(Apply the same `@Flag var noUI` + `unitOnly: noUI` to `ScreensCommand` and `BranchCommand`. ArgumentParser renders `--no-ui` from `noUI`.)

- [ ] **Step 2: Add the single-stage commands**

`StageCommands.swift`:
```swift
import ArgumentParser
import Foundation
import GateKit

struct FormatCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "format", abstract: "Check (or fix) formatting.")
    @Flag(name: .long, help: "Rewrite files in place instead of just checking.") var fix = false
    @OptionGroup var common: CommonOptions
    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let argv = fix ? ["swiftformat", "."] : ["swiftformat", "--lint", "."]
        let result = try SystemCommandRunner().run(argv, cwd: cwd)
        if !result.stdout.isEmpty { print(result.stdout) }
        if !result.succeeded { throw ExitCode.failure }
    }
}

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "lint", abstract: "Run swiftlint (strict).")
    @OptionGroup var common: CommonOptions
    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let result = try SystemCommandRunner().run(["swiftlint", "lint", "--strict", "--quiet"], cwd: cwd)
        if !result.stdout.isEmpty { print(result.stdout) }
        if !result.succeeded { throw ExitCode.failure }
    }
}
```

- [ ] **Step 3: Add the `verify-stamp` command**

`StampCommands.swift`:
```swift
import ArgumentParser
import Foundation
import GateKit

struct VerifyStampCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify-stamp",
        abstract: "Fail if any screen changed since its last green gate (Xcode build-phase guard)."
    )
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let skip = ProcessInfo.processInfo.environment["GATE_SKIP_STAMP"] == "1"
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let result = try gate.verifyStamp(skip: skip)
        if result.skipped {
            print("⚠︎ gate verify-stamp skipped (GATE_SKIP_STAMP=1)")
            return
        }
        if result.passed {
            print("✔ gate stamp current")
            return
        }
        for name in result.staleScreens {
            print("✘ \(name) changed since last green gate — run 'gate screen \(name)'")
        }
        throw ExitCode.failure
    }
}
```

- [ ] **Step 4: Register the subcommands**

`Gate.swift` — extend the subcommand list:
```swift
        subcommands: [
            All.self, ScreenCommand.self, ScreensCommand.self, BranchCommand.self,
            StagedCommand.self, FormatCommand.self, LintCommand.self, VerifyStampCommand.self
        ],
```

- [ ] **Step 5: Build + verify the surface**

Run: `cd /Users/rojo/Documents/SWIFT-BASE-CLASS && swift build --package-path Tooling && swift run --package-path Tooling gate --help`
Expected: help lists `staged`, `format`, `lint`, `verify-stamp` alongside the Phase 1 commands. Also `swift run --package-path Tooling gate verify-stamp` (from repo root) prints either `✔ gate stamp current` or `✘ <Screen> changed …` and exits accordingly.

- [ ] **Step 6: Commit**

```bash
swiftformat Tooling
git add Tooling/Sources/gate
git commit -m "feat(gate): add verify-stamp, format, lint, staged CLI commands

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone D — Bind all four enforcers + additive CI

### Task 12: rewrite lefthook hooks to call `gate`

**Files:**
- Modify: `lefthook.yml`
- Modify: `.gitignore` (ignore `.gate/`)

No behavior loss: same format + lint, **plus** scoped unit tests on pre-commit and the scoped unit+UI gate on pre-push. The `./gate` wrapper builds the tool once and forwards args.

- [ ] **Step 1: Ignore the stamp directory**

Append to `.gitignore`:
```
# gate engine (local verification stamp + eco ledger)
.gate/
```

- [ ] **Step 2: Rewrite `lefthook.yml`**

```yaml
# Lefthook git hooks — all enforcement routes through the one `gate` binary.
# Install once after cloning:  lefthook install
# Docs: https://lefthook.dev

pre-commit:
  parallel: false
  commands:
    # 1. Auto-fix formatting on staged Swift files, then re-stage them.
    format:
      glob: "*.swift"
      run: ./gate format --fix && git add {staged_files}
      stage_fixed: true
    # 2. Strict lint (warnings are errors).
    lint:
      glob: "*.swift"
      run: ./gate lint
    # 3. Scoped UNIT tests for the screens with staged changes (UI excluded — kept fast).
    unit:
      glob: "*.swift"
      run: ./gate staged --no-ui

commit-msg:
  commands:
    conventional:
      run: bash scripts/check-commit-msg.sh {1}

pre-push:
  commands:
    # Last line before code leaves the machine: affected screens, unit + UI.
    gate-branch:
      run: ./gate branch
```

- [ ] **Step 3: Verify a clean commit still passes**

Run (touch a trivial doc to stage something non-Swift, then a no-op Swift change):
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
lefthook run pre-commit
```
Expected: format + lint run via `./gate`; `./gate staged --no-ui` runs (with nothing staged it resolves to zero screens → no tests → passes). No errors.
> If `lefthook run pre-commit` reports the stamp test stage trying to launch a simulator, that's expected only when a `Features/<Screen>` file is staged. With nothing staged it is a no-op.

- [ ] **Step 4: Commit**

```bash
git add lefthook.yml .gitignore
git commit -m "feat(gate): route lefthook pre-commit/pre-push through gate

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Xcode build-phase guard (`gate verify-stamp`)

**Files:**
- Modify: `SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj/project.pbxproj`

Add a Run-Script build phase to the **app** target (`SwiftBaseClassWAC`), modeled on the existing `SwiftLint` phase (`C100000000000000000000C1`). It runs `gate verify-stamp`, skips in CI, and honors `GATE_SKIP_STAMP`.

- [ ] **Step 1: Identify the app target's build-phase list**

Run: `grep -n "name = SwiftBaseClassWAC;" SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj/project.pbxproj`
Find the `PBXNativeTarget` whose `name = SwiftBaseClassWAC;` (the app, not Tests/UITests) and note its `buildPhases = ( … );` list and the existing `C100000000000000000000C1 /* SwiftLint */` entry.

- [ ] **Step 2: Add a new shell-script phase object**

In the `/* Begin PBXShellScriptBuildPhase section */ … /* End … */` block, add after the `SwiftLint` phase:
```
		C200000000000000000000C2 /* Gate verify-stamp */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
			);
			name = "Gate verify-stamp";
			outputFileListPaths = (
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "# Stuck-until-green guard: fail the build if a screen changed since its last green gate.\nif [ -n \"$CI\" ]; then exit 0; fi\nif [ \"$GATE_SKIP_STAMP\" = \"1\" ]; then echo \"warning: gate verify-stamp skipped (GATE_SKIP_STAMP=1)\"; exit 0; fi\nGATE=\"$SRCROOT/../gate\"\nif [ ! -x \"$GATE\" ]; then echo \"warning: ./gate not found at $GATE — skipping stamp check\"; exit 0; fi\n\"$GATE\" verify-stamp || { echo \"error: gate verify-stamp failed — run the gate for the changed screen(s) to re-green\"; exit 1; }\n";
		};
```
> `$SRCROOT` is `…/SwiftBaseClassWAC` (the project dir); the wrapper lives one level up at repo root, hence `$SRCROOT/../gate`. The phase is best placed **before** `Sources` so it short-circuits early — but after `SwiftLint` is acceptable.

- [ ] **Step 3: Reference the phase in the app target's `buildPhases`**

Add `C200000000000000000000C2 /* Gate verify-stamp */,` to the app target's `buildPhases = ( … );` array (the same target that lists `C100000000000000000000C1`).

- [ ] **Step 4: Verify the project still parses and builds**

Run:
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
plutil -lint SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj/project.pbxproj
xcodebuild -project SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj -scheme SwiftBaseClassWAC -showBuildSettings >/dev/null && echo OK
```
Expected: `plutil` says "OK"; `showBuildSettings` exits 0 (`OK`). A full `xcodebuild build` after a green `./gate all` should succeed; after editing a screen without re-gating, the build fails with the `error: gate verify-stamp failed …` line (manual spot check; `GATE_SKIP_STAMP=1 xcodebuild …` bypasses).

- [ ] **Step 5: Commit**

```bash
git add SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj/project.pbxproj
git commit -m "feat(gate): add Xcode build-phase stuck-until-green guard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: additive CI enhancement

**Files:**
- Modify: `.github/workflows/ci.yml`

Each addition is separable and must not change the meaning of an existing step. Existing `lint`, `test`, `archive` jobs keep their exact semantics.

- [ ] **Step 1: Add dependency caching to the `test` job**

In `ci.yml`, inside `jobs.test.steps`, **after** `actions/checkout` and **before** the build, add:
```yaml
      - name: Cache SwiftPM & DerivedData
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/Developer/Xcode/DerivedData
            Tooling/.build
          key: ${{ runner.os }}-spm-dd-${{ hashFiles('Tooling/Package.resolved', 'SwiftBaseClassWAC/**/*.swift') }}
          restore-keys: |
            ${{ runner.os }}-spm-dd-
```
(Identical build results, just faster/greener. No existing step changes.)

- [ ] **Step 2: Add a NEW scoped fast-check job (does not replace `test`)**

Append a new job (PR-only; the full `test` job remains the source of truth):
```yaml
  fast-check:
    name: Fast scoped gate (PR)
    if: github.event_name == 'pull_request'
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0          # gate branch needs history to diff against the base
      - name: Select Xcode 26
        run: |
          XC=$(ls -d /Applications/Xcode_26*.app 2>/dev/null | sort -V | tail -1)
          [ -n "$XC" ] && sudo xcode-select -s "$XC/Contents/Developer"
          xcodebuild -version
      - name: Install SwiftLint & SwiftFormat
        run: brew install swiftlint swiftformat
      - name: Scoped gate for changed screens
        run: ./gate branch --base "origin/${{ github.base_ref }}"
```
> This job is informational/fast; it does not gate the merge unless added to required checks. The existing `lint` and `test` jobs remain the required checks. If `gate branch` resolves to `.all` (shared-dir change), it runs the full suite — acceptable.

- [ ] **Step 3: Broaden branch triggers additively**

Change only the `push` trigger to also build feature branches, leaving PR behavior intact:
```yaml
on:
  pull_request:
  push:
    branches: [main, Develop, "feat/**", "fix/**"]
  workflow_dispatch:
```
(Existing `main`/`Develop` behavior is unchanged; feature branches now *also* get CI.)

- [ ] **Step 4: Validate the workflow**

Run:
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"
```
Expected: `yaml ok`. (Functional CI verification happens on the next push/PR; nothing green today is removed.)

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add caching, scoped fast-check, and broader branch triggers (additive)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of done (Phase 2A)

- `cd Tooling && swift test` is green (all GateKit unit tests incl. the new stamp/hash/verify/staged/unit-only suites).
- `./gate verify-stamp` exits 0 right after a green `./gate all`, and exits 1 naming the screen after an un-gated edit; `GATE_SKIP_STAMP=1 ./gate verify-stamp` prints a warning and exits 0.
- `./gate staged --no-ui`, `./gate format --fix`, `./gate lint` all run and exit correctly.
- lefthook `pre-commit` runs scoped format + lint on the **staged files** (preserving the old, fast, no-behavior-loss scoping — `swiftformat`/`swiftlint` directly, not the repo-wide `gate format`/`gate lint`, which would reformat/stage unrelated files) **plus** the new gate-powered `gate staged --no-ui` scoped unit tests; `pre-push` runs `gate branch`. (`gate format`/`gate lint` remain as manual whole-repo commands.) No behavior regression vs. the old hooks.
- The app target has a `Gate verify-stamp` build phase that blocks ⌘R on a stale screen and is bypassable via `GATE_SKIP_STAMP=1` / skipped in CI.
- CI is additively enhanced (cache + fast-check job + broader triggers); the existing `lint`/`test`/`archive` jobs are byte-for-byte semantically unchanged and nothing green today goes red.
- `.gate/` is gitignored.

## Out of scope (later Phase 2 plans)
- **2B — stronger/architectural lint** (custom `.swiftlint.yml` rules: `view_no_networking`, `viewmodel_mainactor`, `no_print`, `screen_naming`, …).
- **2C — `gate audit`** (the industrial punch-list + health score + GitHub annotations).
- **Green-compute caching** (skip-on-unchanged short-circuit reusing these hashes; the Eco ledger). The stamp built here is the cache key that subsystem will consume.
