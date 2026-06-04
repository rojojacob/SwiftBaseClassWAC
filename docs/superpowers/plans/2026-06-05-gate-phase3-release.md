# Gate Phase 3 — Release Stages (`gate archive` / `gate testflight`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two deliberate, keyword-only release stages — `gate archive` (unsigned `.xcarchive`) and `gate testflight` (delegates to the existing `fastlane beta` lane) — runnable standalone or appended to a green gate run via `--archive`/`--testflight`, and NEVER part of the automatic pipeline.

**Architecture:** Two new `Stage` conformers (`ArchiveStage`, `TestFlightStage`) drive `xcodebuild archive` and `bundle exec fastlane <lane>` through the existing `CommandRunner` seam, so their argv is unit-tested without shelling out. They are excluded from `Pipeline.standard` (which only builds `format/lint/test`); the CLI runs them explicitly — `gate archive`/`gate testflight` standalone, or after a passing gate when `--archive`/`--testflight` is set. Like `BuildTestStage`, the archive build passes `GATE_SKIP_STAMP=1` so the in-build verify-stamp guard doesn't deadlock the gate's own build. Release knobs (`archive_path`, `testflight_lane`) live in an optional `release:` block in `gate.yml` with sensible defaults.

**Tech Stack:** Swift 5.9 / SwiftPM (`Tooling/`), Swift Testing, ArgumentParser. `xcodebuild archive`, `bundle exec fastlane`.

**Conventions (carried from Phase 1/2 — do not violate):**
- swiftlint-`--strict`-clean: no `print` in GateKit (CLI `print` ok), no force-unwrap/`try!`, lines ≤120, type names ≥3, identifier names ≥2, one call-arg-per-line for multiline calls. `.swiftformat --commas inline`, `--swiftversion 5.0`. Run `swiftformat Tooling` before committing.
- **Swift Testing** (`@Test`/`#expect`/`#require`), NOT XCTest. `import Foundation` where `URL`/`Data` used.
- NEVER `git commit --no-verify`. Conventional Commits. Every commit ends with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- SourceKit "No such module"/"Cannot find type" are FALSE POSITIVES; `cd Tooling && swift test` / `swift build` is ground truth.
- Committing `Tooling/` Swift files runs the live pre-commit gate (`format`/`lint` staged + `./gate staged --no-ui` → Tooling change → no app screen → fast no-op). Expected; let it run. Stay on branch `feat/wac-ios-standard`.
- **NEVER actually run `gate testflight` / `fastlane beta`** during implementation — it builds a signed `.ipa` and UPLOADS to real TestFlight. It is verified by argv unit test + the CLI building only. `gate archive` (unsigned, local, no upload) IS safe to run end-to-end.

**Existing surface to build on (assume present):**
- `enum StageID: String { format, lint, test }`; `enum Outcome { passed, failed }`; `struct Finding`; `struct StageResult { stage; outcome; findings; summary; passed }`; `protocol Stage { var id: StageID; func run(_ scope: ResolvedScope, _ ctx: GateContext) throws -> StageResult }`.
- `struct GateContext { config; runner; repoRoot }`. `BuildTestStage` already appends `"GATE_SKIP_STAMP=1"` to its xcodebuild argv (mirror that).
- `GateConfig` (Codable, Yams) with `project`, `scheme`, `targets`, `simulator`, `baseBranch`, `conventions`, `stages`, optional `thresholds`. `GateConfig.parse(_:)` / `.load(from:)`.
- `Pipeline.standard(for:unitOnly:) throws` maps `format/lint/test`, `build`→skip, unknown → `PipelineError.unknownStage`. `Pipeline.run(scope:context:)` fail-fast.
- CLI `Sources/gate/{Gate,CommonOptions,CommandSupport,Commands,StageCommands,StampCommands,AuditCommand}.swift`. `CommandSupport.execute(common:scope:unitOnly:)` runs `GateRunner.live(...).run(scope, unitOnly:)`, prints the report, throws `ExitCode.failure` on a non-passing report. `GateRunner.live(configPath:repoRoot:)`.
- Test support: `FakeCommandRunner` (`stub(whenContains:result:)`, `calls`), `makeTestConfig(stages:)`, `makeContext(runner:)`.
- fastlane lanes already exist (`fastlane/Fastfile`): `test`, `certificates`, `beta` (signed build + TestFlight upload), `release`. Invoked `bundle exec fastlane <lane>` from repo root.

---

## File Structure
**New GateKit (`Tooling/Sources/GateKit/Stages/`):** `ArchiveStage.swift`, `TestFlightStage.swift`.
**Modified GateKit:** `Stages/Stage.swift` (StageID += archive/testflight), `Pipeline/Pipeline.swift` (reject keyword stages with a clear error), `Config/GateConfig.swift` (optional `release` block).
**New CLI (`Tooling/Sources/gate/`):** `ReleaseCommands.swift` (`ArchiveCommand`, `TestFlightCommand`); modify `Gate.swift`, `Commands.swift`, `CommandSupport.swift` (`--archive`/`--testflight`).
**New tests:** `ArchiveStageTests.swift`, `TestFlightStageTests.swift`, plus additions to `PipelineTests.swift`, `GateConfigTests.swift`.
**Modified config:** `gate.yml` (optional `release:` block), `docs/release.md` (new), `.gitignore` (ignore `build/`).

---

## Milestone A — keyword stages (engine)

### Task 1: `StageID` += `.archive`/`.testflight`; `Pipeline.standard` rejects them

**Files:** Modify `Tooling/Sources/GateKit/Stages/Stage.swift`, `Tooling/Sources/GateKit/Pipeline/Pipeline.swift`, `Tooling/Tests/GateKitTests/PipelineTests.swift`.

- [ ] **Step 1: Extend `StageID`** in `Stage.swift`:
```swift
public enum StageID: String, Equatable, Sendable {
    case format
    case lint
    case test
    case archive
    case testflight
}
```

- [ ] **Step 2: Write the failing test** — `PipelineTests.swift`, add:
```swift
@Test func standardFactoryRejectsKeywordStages() {
    // archive/testflight are CLI keyword stages, never part of the default pipeline.
    #expect(throws: PipelineError.self) {
        _ = try Pipeline.standard(for: makeTestConfig(stages: "[format, archive]"))
    }
}
```

- [ ] **Step 3: Run, expect FAIL** — `cd Tooling && swift test --filter standardFactoryRejectsKeywordStages` (it currently throws `unknownStage("archive")`, which IS a `PipelineError`, so this may already pass; the point of the next step is a CLEARER error). Proceed to make the message explicit.

- [ ] **Step 4: Add an explicit case** to `Pipeline.standard(for:unitOnly:)` switch, before `default`:
```swift
            case "archive", "testflight":
                throw PipelineError.keywordStage(name)
```
and add the case to `PipelineError`:
```swift
public enum PipelineError: Error, Equatable {
    case unknownStage(String)
    case noStages
    case keywordStage(String)
}
```

- [ ] **Step 5: Run, expect PASS** — `cd Tooling && swift test` (full suite green; the new test passes via the explicit `keywordStage`).

- [ ] **Step 6: Commit**
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
git add Tooling/Sources/GateKit/Stages/Stage.swift Tooling/Sources/GateKit/Pipeline/Pipeline.swift Tooling/Tests/GateKitTests/PipelineTests.swift
git commit -m "feat(release): add archive/testflight StageIDs; reject them as pipeline stages

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `ArchiveStage`

**Files:** Create `Tooling/Sources/GateKit/Stages/ArchiveStage.swift`, `Tooling/Tests/GateKitTests/ArchiveStageTests.swift`.

- [ ] **Step 1: Write the failing test**

`ArchiveStageTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func archiveRunsUnsignedXcodebuildArchive() throws {
    let runner = FakeCommandRunner()
    let result = try ArchiveStage().run(
        ResolvedScope(kind: .all, screens: []), makeContext(runner: runner)
    )
    let call = try #require(runner.calls.first)
    #expect(call.contains("xcodebuild"))
    #expect(call.contains("archive"))
    #expect(call.contains("-scheme"))
    #expect(call.contains("CODE_SIGNING_ALLOWED=NO")) // unsigned
    #expect(call.contains("GATE_SKIP_STAMP=1"))        // don't deadlock on the build-phase guard
    #expect(call.contains { $0.hasPrefix("-archivePath") || $0.hasSuffix(".xcarchive") })
    #expect(result.passed)
}

@Test func archiveFailsAndSurfacesOutput() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "archive", result: ProcessResult(exitCode: 65, stdout: "", stderr: "ARCHIVE FAILED"))
    let result = try ArchiveStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(result.summary.contains("ARCHIVE FAILED"))
}
```

- [ ] **Step 2: Run, expect FAIL** — cannot find `ArchiveStage`.

- [ ] **Step 3: Implement**

`ArchiveStage.swift`:
```swift
/// Keyword stage: builds an UNSIGNED `.xcarchive` (a local release-build check).
/// Never part of the automatic pipeline — run via `gate archive` or `--archive`.
public struct ArchiveStage: Stage {
    public let id: StageID = .archive
    public init() {}

    public func run(_: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let config = context.config
        let archivePath = config.release?.archivePath ?? "build/\(config.scheme).xcarchive"
        let argv = [
            "xcodebuild", "archive",
            "-project", config.project,
            "-scheme", config.scheme,
            "-archivePath", archivePath,
            "-destination", "generic/platform=iOS",
            "CODE_SIGNING_ALLOWED=NO",
            // Skip the in-build verify-stamp guard during the gate's own archive build.
            "GATE_SKIP_STAMP=1"
        ]
        let result = try context.runner.run(argv, cwd: context.repoRoot)
        return StageResult(
            stage: .archive,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded
                ? "archived → \(archivePath)"
                : "archive failed:\n\(result.stdout)\(result.stderr)"
        )
    }
}
```
> Note: `config.release?.archivePath` is added in Task 4. Until then, write `config.release?.archivePath` — `GateConfig` gains the optional `release` in Task 4 (do Task 4 before running the full suite, or temporarily hardcode `"build/\(config.scheme).xcarchive"` and switch to the config form in Task 4). To keep this task self-contained, implement Task 4 immediately after if executing strictly in order.

- [ ] **Step 4: Run, expect PASS** (after Task 4's `release` exists). **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Stages/ArchiveStage.swift Tooling/Tests/GateKitTests/ArchiveStageTests.swift
git commit -m "feat(release): add ArchiveStage (unsigned xcarchive)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `TestFlightStage`

**Files:** Create `Tooling/Sources/GateKit/Stages/TestFlightStage.swift`, `Tooling/Tests/GateKitTests/TestFlightStageTests.swift`.

- [ ] **Step 1: Write the failing test**

`TestFlightStageTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func testFlightDelegatesToFastlaneBetaLane() throws {
    let runner = FakeCommandRunner()
    let result = try TestFlightStage().run(
        ResolvedScope(kind: .all, screens: []), makeContext(runner: runner)
    )
    let call = try #require(runner.calls.first)
    #expect(call == ["bundle", "exec", "fastlane", "beta"]) // default lane
    #expect(result.passed)
}

@Test func testFlightFailsWhenFastlaneFails() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "fastlane", result: ProcessResult(exitCode: 1, stdout: "", stderr: "upload failed"))
    let result = try TestFlightStage().run(ResolvedScope(kind: .all, screens: []), makeContext(runner: runner))
    #expect(result.passed == false)
    #expect(result.summary.contains("upload failed"))
}
```

- [ ] **Step 2: Run, expect FAIL** — cannot find `TestFlightStage`.

- [ ] **Step 3: Implement**

`TestFlightStage.swift`:
```swift
/// Keyword stage: delegates a signed build + TestFlight upload to the project's
/// fastlane lane (default `beta`). Never automatic — run via `gate testflight` or
/// `--testflight`. The gate does not manage signing; fastlane (match) does.
public struct TestFlightStage: Stage {
    public let id: StageID = .testflight
    public init() {}

    public func run(_: ResolvedScope, _ context: GateContext) throws -> StageResult {
        let lane = context.config.release?.testflightLane ?? "beta"
        let result = try context.runner.run(["bundle", "exec", "fastlane", lane], cwd: context.repoRoot)
        return StageResult(
            stage: .testflight,
            outcome: result.succeeded ? .passed : .failed,
            findings: [],
            summary: result.succeeded
                ? "uploaded to TestFlight via fastlane \(lane)"
                : "testflight failed:\n\(result.stdout)\(result.stderr)"
        )
    }
}
```

- [ ] **Step 4: Run, expect PASS** (after Task 4). **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Stages/TestFlightStage.swift Tooling/Tests/GateKitTests/TestFlightStageTests.swift
git commit -m "feat(release): add TestFlightStage (delegates to fastlane lane)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone B — config + CLI

### Task 4: optional `release` block in `GateConfig`

**Files:** Modify `Tooling/Sources/GateKit/Config/GateConfig.swift`, `Tooling/Tests/GateKitTests/GateConfigTests.swift`.

- [ ] **Step 1: Write the failing test** — `GateConfigTests.swift`, add:
```swift
@Test func parsesOptionalReleaseBlock() throws {
    let yaml = """
    project: App/App.xcodeproj
    scheme: App
    targets: { app: App, unit: AppTests, ui: AppUITests }
    simulator: "iPhone 16 Pro"
    base_branch: main
    conventions:
      features_dir: App/App/Features
      unit_dir: App/AppTests
      ui_dir: App/AppUITests
      test_glob: "{Name}*Tests.swift"
      shared_dirs: [Core]
    stages: [format, lint, test]
    release: { archive_path: build/App.xcarchive, testflight_lane: beta }
    """
    let config = try GateConfig.parse(yaml)
    #expect(config.release?.archivePath == "build/App.xcarchive")
    #expect(config.release?.testflightLane == "beta")
}

@Test func releaseIsOptional() {
    #expect(makeTestConfig().release == nil)
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** — in `GateConfig.swift` add the type + optional property + CodingKeys case:
```swift
public struct GateRelease: Codable, Equatable, Sendable {
    public let archivePath: String?
    public let testflightLane: String?

    enum CodingKeys: String, CodingKey {
        case archivePath = "archive_path"
        case testflightLane = "testflight_lane"
    }
}
```
Add `public let release: GateRelease?` to `GateConfig` and `case release` to its `CodingKeys`. Both fields optional → absent keys decode to nil; an absent `release:` block decodes to nil.

- [ ] **Step 4: Run, expect PASS** (`swift test --filter GateConfigTests`). **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Config/GateConfig.swift Tooling/Tests/GateKitTests/GateConfigTests.swift
git commit -m "feat(release): add optional release block (archive_path, testflight_lane)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: standalone `gate archive` / `gate testflight` commands

**Files:** Create `Tooling/Sources/gate/ReleaseCommands.swift`; modify `Tooling/Sources/gate/Gate.swift`.

CLI wiring (verified by `gate --help` + a real `gate archive` run). Thin shell over the stages.

- [ ] **Step 1: Implement `ReleaseCommands.swift`**
```swift
import ArgumentParser
import Foundation
import GateKit

private func runReleaseStage(_ stage: any Stage, config configPath: String) throws {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let configURL = URL(fileURLWithPath: configPath, relativeTo: cwd)
    let config = try GateConfig.load(from: configURL)
    let context = GateContext(config: config, runner: SystemCommandRunner(), repoRoot: cwd)
    let result = try stage.run(ResolvedScope(kind: .all, screens: []), context)
    print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
    if !result.passed { throw ExitCode.failure }
}

struct ArchiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "archive",
        abstract: "Build an unsigned .xcarchive (keyword stage; never automatic)."
    )
    @OptionGroup var common: CommonOptions
    func run() throws { try runReleaseStage(ArchiveStage(), config: common.config) }
}

struct TestFlightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "testflight",
        abstract: "Signed build + TestFlight upload via the fastlane lane (keyword stage)."
    )
    @OptionGroup var common: CommonOptions
    func run() throws { try runReleaseStage(TestFlightStage(), config: common.config) }
}
```
> This requires `GateContext`, `Stage`, `ResolvedScope`, `ArchiveStage`, `TestFlightStage` to be `public` (they are). `runReleaseStage` takes `any Stage`.

- [ ] **Step 2: Register** in `Gate.swift` — append `ArchiveCommand.self, TestFlightCommand.self` to the `subcommands` array.

- [ ] **Step 3: Build + verify the surface, then a REAL unsigned archive**
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
swift build --package-path Tooling && swift run --package-path Tooling gate --help | grep -E 'archive|testflight'
./gate archive          # real unsigned xcodebuild archive — minutes; writes build/<scheme>.xcarchive
ls -d build/*.xcarchive && echo "ARCHIVE OK"
```
Expected: help lists `archive` + `testflight`; `./gate archive` prints `✔ archive: archived → build/SwiftBaseClassWAC.xcarchive` and the `.xcarchive` exists. (Do NOT run `./gate testflight` — it uploads to real TestFlight.)

- [ ] **Step 4: Ignore the build output** — append to `.gitignore`:
```
# release build output (xcarchive / ipa)
build/
```

- [ ] **Step 5: Commit**
```bash
swiftformat Tooling
git add Tooling/Sources/gate/ReleaseCommands.swift Tooling/Sources/gate/Gate.swift .gitignore
git commit -m "feat(release): add gate archive + gate testflight CLI commands

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `--archive` / `--testflight` flags on the scope commands

**Files:** Modify `Tooling/Sources/gate/CommandSupport.swift`, `Tooling/Sources/gate/Commands.swift`.

After a GREEN gate run, optionally append the keyword stage(s). A failing gate never reaches archive/testflight.

- [ ] **Step 1: Extend `CommandSupport.execute`**

`CommandSupport.swift` — replace `execute(...)` with:
```swift
    static func execute(
        common: CommonOptions,
        scope rawScope: ScopeKind,
        unitOnly: Bool = false,
        archive: Bool = false,
        testflight: Bool = false
    ) throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let gate = try GateRunner.live(configPath: configURL, repoRoot: cwd)
        let scope = applyDefaults(rawScope, config: gate.config)
        let report = try gate.run(scope, unitOnly: unitOnly)
        printReport(report)
        if !report.passed { throw ExitCode.failure }

        // Keyword release stages only run AFTER a green gate, and only when requested.
        let context = GateContext(config: gate.config, runner: SystemCommandRunner(), repoRoot: cwd)
        if archive { try runRelease(ArchiveStage(), context) }
        if testflight { try runRelease(TestFlightStage(), context) }
    }

    private static func runRelease(_ stage: any Stage, _ context: GateContext) throws {
        let result = try stage.run(ResolvedScope(kind: .all, screens: []), context)
        print("\(result.passed ? "✔" : "✘") \(result.stage.rawValue): \(result.summary)")
        if !result.passed { throw ExitCode.failure }
    }
```
(`CommandSupport.swift` needs `import GateKit` + `import Foundation` — already present.)

- [ ] **Step 2: Add the flags** in `Commands.swift` to `All`, `ScreenCommand`, `ScreensCommand`, `BranchCommand`, `StagedCommand`. For each, add:
```swift
    @Flag(name: .long, help: "After a green gate, build an unsigned archive.") var archive = false
    @Flag(name: .long, help: "After a green gate, upload to TestFlight via fastlane.") var testflight = false
```
and thread them into the `execute(...)` call, e.g. for `All`:
```swift
    func run() throws {
        try CommandSupport.execute(common: common, scope: .all, archive: archive, testflight: testflight)
    }
```
(Apply the same pattern to all five commands; `ScreenCommand`/`ScreensCommand`/`BranchCommand`/`StagedCommand` already pass `unitOnly: noUI` — add `archive: archive, testflight: testflight` alongside.)

- [ ] **Step 3: Build + verify the flags parse**
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
swift build --package-path Tooling && swift run --package-path Tooling gate all --help | grep -E 'archive|testflight'
```
Expected: `gate all --help` shows `--archive` and `--testflight`. (Do NOT run `gate all --testflight`.)

- [ ] **Step 4: Commit**
```bash
swiftformat Tooling
git add Tooling/Sources/gate/CommandSupport.swift Tooling/Sources/gate/Commands.swift
git commit -m "feat(release): add --archive/--testflight flags after a green gate

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone C — wire `gate.yml` + docs

### Task 7: `gate.yml` release block + `docs/release.md`

**Files:** Modify `gate.yml`; create `docs/release.md`.

- [ ] **Step 1: Add the release block to `gate.yml`** (append):
```yaml
release:
  archive_path: build/SwiftBaseClassWAC.xcarchive
  testflight_lane: beta
```

- [ ] **Step 2: Confirm the gate still loads it** — `./gate all --help >/dev/null && echo "config ok"` (a malformed `gate.yml` would fail to load). Then `cd Tooling && swift test` is still green.

- [ ] **Step 3: Write `docs/release.md`**
```markdown
# Releasing (keyword stages)

Archive and TestFlight are **deliberate, keyword-only** stages — never part of the
automatic `format → lint → build → test` pipeline.

```bash
./gate archive                 # build an UNSIGNED .xcarchive (local release-build check)
./gate testflight              # signed build + TestFlight upload via the fastlane `beta` lane
./gate all --archive           # run the full gate, then archive only if it's green
./gate branch --testflight     # gate the changed screens, then upload if green
```

- `gate archive` writes to `gate.yml > release.archive_path` (default `build/<scheme>.xcarchive`,
  gitignored). It is unsigned (`CODE_SIGNING_ALLOWED=NO`) — for verifying the release build, not distribution.
- `gate testflight` delegates entirely to fastlane (`gate.yml > release.testflight_lane`, default `beta`),
  which handles signing via `fastlane match` and the App Store Connect upload. The gate manages no secrets.
- Both run only after a green gate when invoked via `--archive` / `--testflight`.
```

- [ ] **Step 4: Commit**
```bash
git add gate.yml docs/release.md
git commit -m "feat(release): wire gate.yml release block + document release stages

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of done (Phase 3)
- `cd Tooling && swift test` green (new ArchiveStage/TestFlightStage/release-config suites).
- `gate archive`, `gate testflight`, and `--archive`/`--testflight` on the scope commands all appear in `--help` and parse.
- `./gate archive` runs a REAL unsigned `xcodebuild archive` end-to-end and writes `build/<scheme>.xcarchive` (gitignored). `gate testflight` is unit-tested (argv == `bundle exec fastlane beta`) but NOT executed (it uploads).
- `archive`/`testflight` are rejected as `gate.yml` pipeline stages with a clear `keywordStage` error, and never run in the automatic pipeline.
- Release knobs read from the optional `gate.yml > release` block with sensible defaults.

## Out of scope (later / unchanged)
- The existing CI `archive` job and manual `testflight.yml` keep their exact semantics (spec §16) — not touched.
- fastlane lane internals (signing/match/ASC upload) are owned by `fastlane/Fastfile`, not the gate.
- `gate adopt`/`init` (Phase 4), the guide & AI contract incl. `/ship-testflight` command (Phase 5).
