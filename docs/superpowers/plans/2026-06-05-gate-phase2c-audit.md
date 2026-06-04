# Gate Phase 2C — `gate audit` (Industrial Punch-List) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `gate audit` — scan the repo and emit a prioritized, code-pointing punch-list (`GATE_REPORT.md` + `--json` + GitHub annotations) with a 0–100 health score, plus `--fix` for the deterministic-safe class; non-blocking by default, gating only under `--enforce` below `thresholds.health_min`.

**Architecture:** A pure `Auditor` (GateKit) aggregates findings from three reliable sources via the existing `CommandRunner`/`FileFinder` seams: SwiftLint's machine-readable `--reporter json` (every builtin + the §10 custom rules, each carrying file/line/rule/severity/reason), SwiftFormat drift (`--lint`), and a "screen with no tests" heuristic (`ScopeResolver.allScreens` → empty test classes). Findings map to a four-level `AuditSeverity`; a deterministic formula yields the health score. Renderers turn the `AuditReport` into Markdown / JSON / GitHub `::annotation` lines. The CLI wires it up; `--fix` delegates to `swiftformat .` + `swiftlint --fix`. Everything is unit-tested by feeding the fake runner canned SwiftLint JSON — no real tools shell out in tests.

**Tech Stack:** Swift 5.9 / SwiftPM (`Tooling/`), Swift Testing, ArgumentParser, `JSONDecoder`/`JSONEncoder`. SwiftLint `--reporter json`, SwiftFormat `--lint`.

**Conventions (carried from Phase 1/2A/2B — do not violate):**
- swiftlint-`--strict`-clean: no `print` in GateKit (CLI `print` ok), no force-unwrap/`try!`/`force_try`, lines ≤120, type names ≥3, identifier names ≥2, one call-arg-per-line for multiline calls. `.swiftformat --commas inline` (no trailing commas), `--swiftversion 5.0`. Run `swiftformat Tooling` before committing.
- **Swift Testing** (`@Test`/`#expect`/`#require`), NOT XCTest. `import Foundation` where `URL`/`Data` used.
- NEVER `git commit --no-verify`. Conventional Commits. Every commit ends with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- SourceKit "No such module"/"Cannot find type" are FALSE POSITIVES; `cd Tooling && swift test` / `swift build` is ground truth.
- New GateKit/gate files auto-compile (SwiftPM). Stay on branch `feat/wac-ios-standard`.
- Committing Swift files runs the live pre-commit gate (format/lint on staged swift + `gate staged --no-ui`); a `Tooling/` change resolves to no app screen → a fast no-op. That's expected.

**Existing engine surface to build on (assume present):**
- `protocol CommandRunner { func run(_ argv:[String], cwd:URL, env:[String:String]) throws -> ProcessResult }`; `ProcessResult { exitCode; stdout; stderr; succeeded }`. `FakeCommandRunner` has `stub(whenContains:result:)` + `calls`.
- `protocol FileFinder { files(in:matching:); subdirectories(of:) }`; `ScopeResolver(config:runner:finder:repoRoot:)` with public `allScreens() -> [Screen]`; `Screen { name; codePath; unitTestClasses; uiTestClasses; unitTestFiles; uiTestFiles }`.
- `GateConfig` (Codable) with `conventions`, `project`, `scheme`, etc., loaded by `GateConfig.load(from:)` / `GateConfig.parse(_:)` (Yams). `GateContext { config; runner; repoRoot }`.
- `GateRunner.live(configPath:repoRoot:)` wiring System* impls. CLI: `Sources/gate/{Gate,CommonOptions,CommandSupport,Commands,StageCommands,StampCommands}.swift`.
- Test support: `TestSupport.makeTestConfig(stages:)`, `makeContext(runner:)`, `FakeFileFinder`, `FakeFileReader`, `FakeStampStore`.

---

## File Structure
**New GateKit (`Tooling/Sources/GateKit/Audit/`):**
- `AuditSeverity.swift` — `enum AuditSeverity` (critical/high/medium/low) + ordering + weight.
- `AuditFinding.swift` — one finding (severity, file, line, ruleID, title, detail, fix).
- `AuditReport.swift` — findings + computed `healthScore`, `grouped`, `topN(_:)`.
- `SwiftLintJSON.swift` — Codable mirror of `swiftlint --reporter json` + mapping to `AuditFinding` (severity + fix-hint lookup).
- `Auditor.swift` — aggregates lint + format-drift + no-tests findings into an `AuditReport`.
- `AuditRenderer.swift` — `markdown(_:)`, `githubAnnotations(_:)` (JSON via `Codable` on the report).

**Modified GateKit:**
- `Config/GateConfig.swift` — add optional `thresholds: GateThresholds?` (`health_min`).

**New CLI (`Tooling/Sources/gate/`):**
- `AuditCommand.swift` — `gate audit [--fix] [--report PATH] [--annotate] [--enforce]`, registered in `Gate.swift`.

**New tests (`Tooling/Tests/GateKitTests/`):**
- `AuditSeverityTests.swift`, `AuditReportTests.swift`, `SwiftLintJSONTests.swift`, `AuditorTests.swift`, `AuditRendererTests.swift`.

**Modified config:** `.github/workflows/ci.yml` (additive audit step), `gate.yml` (optional `thresholds`).

---

## Milestone A — Audit model + SwiftLint JSON ingestion

### Task 1: `AuditSeverity`

**Files:** Create `Tooling/Sources/GateKit/Audit/AuditSeverity.swift`, `Tooling/Tests/GateKitTests/AuditSeverityTests.swift`.

- [ ] **Step 1: Failing test**

`AuditSeverityTests.swift`:
```swift
import Testing
@testable import GateKit

@Test func severitiesOrderCriticalHighestAndCarryWeight() {
    #expect(AuditSeverity.critical > AuditSeverity.high)
    #expect(AuditSeverity.high > AuditSeverity.medium)
    #expect(AuditSeverity.medium > AuditSeverity.low)
    #expect(AuditSeverity.critical.weight > AuditSeverity.low.weight)
    #expect(AuditSeverity.allCases.count == 4)
}
```

- [ ] **Step 2: Run, expect FAIL** — `cd Tooling && swift test --filter AuditSeverityTests` → cannot find `AuditSeverity`.

- [ ] **Step 3: Implement**

`AuditSeverity.swift`:
```swift
/// Four-level audit priority, ordered so `.critical` is the highest.
public enum AuditSeverity: Int, Codable, Comparable, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Penalty applied to the 0–100 health score per finding at this severity.
    public var weight: Int {
        switch self {
        case .critical: return 15
        case .high: return 7
        case .medium: return 3
        case .low: return 1
        }
    }

    /// Stable display label.
    public var label: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}
```

- [ ] **Step 4: Run, expect PASS.** **Step 5: Commit**
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
git add Tooling/Sources/GateKit/Audit/AuditSeverity.swift Tooling/Tests/GateKitTests/AuditSeverityTests.swift
git commit -m "feat(audit): add AuditSeverity (4-level, weighted)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `AuditFinding` + `AuditReport` (health score, grouping, top-N)

**Files:** Create `Tooling/Sources/GateKit/Audit/AuditFinding.swift`, `Audit/AuditReport.swift`, `Tooling/Tests/GateKitTests/AuditReportTests.swift`.

- [ ] **Step 1: Failing test**

`AuditReportTests.swift`:
```swift
import Testing
@testable import GateKit

private func finding(_ sev: AuditSeverity, _ rule: String, line: Int) -> AuditFinding {
    AuditFinding(severity: sev, file: "App/\(rule).swift", line: line,
                 ruleID: rule, title: rule, detail: "because", fix: "do this")
}

@Test func healthScoreSubtractsWeightedPenaltiesFlooredAtZero() {
    let report = AuditReport(findings: [
        finding(.critical, "force_try", line: 1),  // -15
        finding(.medium, "todo", line: 2),         // -3
        finding(.low, "fmt", line: 3)              // -1
    ])
    #expect(report.healthScore == 81) // 100 - 19
}

@Test func emptyReportIsPerfectHealth() {
    #expect(AuditReport(findings: []).healthScore == 100)
}

@Test func healthScoreNeverNegative() {
    let many = (0 ..< 20).map { finding(.critical, "r\($0)", line: $0) }
    #expect(AuditReport(findings: many).healthScore == 0)
}

@Test func groupedSortsBySeverityThenFileLine() {
    let report = AuditReport(findings: [
        finding(.low, "a", line: 5), finding(.critical, "b", line: 2), finding(.critical, "a", line: 9)
    ])
    let order = report.grouped.map(\.severity)
    #expect(order == [.critical, .critical, .low])
    // within a severity, sorted by file then line
    #expect(report.grouped[0].ruleID == "a") // App/a.swift < App/b.swift
}

@Test func topNTakesHighestSeverityFirst() {
    let report = AuditReport(findings: [
        finding(.low, "a", line: 1), finding(.critical, "b", line: 1), finding(.high, "c", line: 1)
    ])
    #expect(report.topN(2).map(\.severity) == [.critical, .high])
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`AuditFinding.swift`:
```swift
/// One prioritized, code-pointing audit item.
public struct AuditFinding: Equatable, Codable, Sendable {
    public let severity: AuditSeverity
    public let file: String
    public let line: Int?
    public let ruleID: String
    public let title: String   // human rule name / subject
    public let detail: String  // the "why"
    public let fix: String     // how to fix it

    public init(
        severity: AuditSeverity,
        file: String,
        line: Int?,
        ruleID: String,
        title: String,
        detail: String,
        fix: String
    ) {
        self.severity = severity
        self.file = file
        self.line = line
        self.ruleID = ruleID
        self.title = title
        self.detail = detail
        self.fix = fix
    }
}
```
> `AuditSeverity` is already `Codable` (declared in Task 1), so `AuditFinding`/`AuditReport` synthesise `Codable` automatically.

`AuditReport.swift`:
```swift
/// The full audit result: findings + a derived 0–100 health score.
public struct AuditReport: Equatable, Codable, Sendable {
    public let findings: [AuditFinding]

    public init(findings: [AuditFinding]) {
        self.findings = findings
    }

    /// 100 minus the summed severity weights, floored at 0.
    public var healthScore: Int {
        let penalty = findings.reduce(0) { $0 + $1.severity.weight }
        return max(0, 100 - penalty)
    }

    /// All findings sorted by severity (critical first), then file, then line.
    public var grouped: [AuditFinding] {
        findings.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            if lhs.file != rhs.file { return lhs.file < rhs.file }
            return (lhs.line ?? 0) < (rhs.line ?? 0)
        }
    }

    /// The highest-priority `n` findings ("fix these first").
    public func topN(_ count: Int) -> [AuditFinding] {
        Array(grouped.prefix(count))
    }
}
```

- [ ] **Step 4: Run, expect PASS** (AuditReportTests + AuditSeverityTests). **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Audit/AuditFinding.swift Tooling/Sources/GateKit/Audit/AuditReport.swift Tooling/Sources/GateKit/Audit/AuditSeverity.swift Tooling/Tests/GateKitTests/AuditReportTests.swift
git commit -m "feat(audit): add AuditFinding + AuditReport (health score, grouping, top-N)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: SwiftLint JSON ingestion → findings

**Files:** Create `Tooling/Sources/GateKit/Audit/SwiftLintJSON.swift`, `Tooling/Tests/GateKitTests/SwiftLintJSONTests.swift`.

- [ ] **Step 1: Failing test** (canned real-shape JSON, incl. a force_try → critical and a warning → medium)

`SwiftLintJSONTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

private let sampleJSON = """
[
  {"character":13,"file":"/repo/App/AView.swift","line":2,"reason":"Force tries should be avoided",
   "rule_id":"force_try","severity":"Error","type":"Force Try"},
  {"character":1,"file":"/repo/App/BView.swift","line":9,"reason":"Prefer isEmpty",
   "rule_id":"empty_count","severity":"Warning","type":"Empty Count"}
]
"""

@Test func parsesSwiftLintJSONIntoFindings() throws {
    let findings = try SwiftLintJSON.findings(fromJSON: Data(sampleJSON.utf8), repoRoot: "/repo")
    #expect(findings.count == 2)
    let forceTry = try #require(findings.first { $0.ruleID == "force_try" })
    #expect(forceTry.severity == .critical)            // safety rule escalated
    #expect(forceTry.file == "App/AView.swift")        // path made repo-relative
    #expect(forceTry.line == 2)
    #expect(forceTry.fix.isEmpty == false)             // has a fix hint
    let emptyCount = try #require(findings.first { $0.ruleID == "empty_count" })
    #expect(emptyCount.severity == .medium)            // warning → medium
}

@Test func emptyJSONArrayYieldsNoFindings() throws {
    #expect(try SwiftLintJSON.findings(fromJSON: Data("[]".utf8), repoRoot: "/repo").isEmpty)
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`SwiftLintJSON.swift`:
```swift
import Foundation

/// Parses `swiftlint --reporter json` output into `AuditFinding`s.
public enum SwiftLintJSON {
    private struct Row: Decodable {
        let file: String
        let line: Int?
        let reason: String
        let ruleID: String
        let severity: String
        let type: String

        enum CodingKeys: String, CodingKey {
            case file, line, reason, severity, type
            case ruleID = "rule_id"
        }
    }

    /// Safety-critical rules outrank a plain SwiftLint "error".
    private static let criticalRules: Set<String> = [
        "force_unwrapping", "force_try", "force_cast"
    ]

    /// Short, actionable fix hints for the rules we see most; generic fallback otherwise.
    private static let fixHints: [String: String] = [
        "force_try": "Replace `try!` with `try` + error handling (do/catch or `try?`).",
        "force_unwrapping": "Replace `!` with `guard let`/`if let` or a default.",
        "force_cast": "Replace `as!` with `as?` and handle the nil case.",
        "empty_count": "Use `isEmpty` instead of comparing `count` to 0.",
        "no_print": "Use `AppLogger` instead of `print`.",
        "view_no_networking": "Move networking into the screen's ViewModel.",
        "viewmodel_no_swiftui": "Drop `import SwiftUI` from the view model; use Observation."
    ]

    public static func findings(fromJSON data: Data, repoRoot: String) throws -> [AuditFinding] {
        let rows = try JSONDecoder().decode([Row].self, from: data)
        let prefix = repoRoot.hasSuffix("/") ? repoRoot : repoRoot + "/"
        return rows.map { row in
            let relative = row.file.hasPrefix(prefix) ? String(row.file.dropFirst(prefix.count)) : row.file
            let severity: AuditSeverity = criticalRules.contains(row.ruleID)
                ? .critical
                : (row.severity.lowercased() == "error" ? .high : .medium)
            return AuditFinding(
                severity: severity,
                file: relative,
                line: row.line,
                ruleID: row.ruleID,
                title: row.type,
                detail: row.reason,
                fix: fixHints[row.ruleID] ?? "See `swiftlint rules \(row.ruleID)`."
            )
        }
    }
}
```

- [ ] **Step 4: Run, expect PASS.** **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Audit/SwiftLintJSON.swift Tooling/Tests/GateKitTests/SwiftLintJSONTests.swift
git commit -m "feat(audit): parse swiftlint JSON into audit findings

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone B — Auditor aggregation + renderers

### Task 4: `Auditor` — aggregate lint + format-drift + no-tests

**Files:** Create `Tooling/Sources/GateKit/Audit/Auditor.swift`, `Tooling/Tests/GateKitTests/AuditorTests.swift`.

- [ ] **Step 1: Failing test** (fake runner returns canned swiftlint JSON + a swiftformat-drift line; fake finder yields a screen with no tests)

`AuditorTests.swift`:
```swift
import Foundation
import Testing
@testable import GateKit

@Test func auditorAggregatesLintFormatAndNoTestFindings() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "--reporter", result: ProcessResult(
        exitCode: 0,
        stdout: """
        [{"file":"/repo/App/App/Features/Counter/CounterView.swift","line":2,
          "reason":"Force tries should be avoided","rule_id":"force_try",
          "severity":"Error","type":"Force Try"}]
        """,
        stderr: ""
    ))
    // swiftformat --lint writes "needs formatting" paths to stderr:
    runner.stub(whenContains: "swiftformat", result: ProcessResult(
        exitCode: 1, stdout: "",
        stderr: "/repo/App/App/Features/Counter/CounterModel.swift:1:1: warning: (indent)\n"
    ))
    let finder = FakeFileFinder()
    finder.subdirsByDirectory["/repo/App/App/Features"] = ["Counter", "Posts"]
    // Counter has a unit test; Posts has none → Posts is a no-tests finding.
    finder.filesByDirectory["/repo/App/AppTests"] = ["/repo/App/AppTests/CounterModelTests.swift"]

    let auditor = Auditor(config: makeTestConfig(), runner: runner, finder: finder,
                          repoRoot: URL(fileURLWithPath: "/repo"))
    let report = try auditor.audit()

    #expect(report.findings.contains { $0.ruleID == "force_try" && $0.severity == .critical })
    #expect(report.findings.contains { $0.ruleID == "swiftformat" && $0.severity == .low })
    #expect(report.findings.contains { $0.ruleID == "no_tests" && $0.file.contains("Posts") && $0.severity == .high })
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`Auditor.swift`:
```swift
import Foundation

/// Scans the repo and aggregates findings from SwiftLint, SwiftFormat drift, and
/// a "screen with no tests" heuristic into an `AuditReport`. All process calls go
/// through `CommandRunner`, so it is unit-tested without real tools.
public struct Auditor {
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

    public func audit() throws -> AuditReport {
        var findings: [AuditFinding] = []
        findings += try lintFindings()
        findings += try formatDriftFindings()
        findings += noTestFindings()
        return AuditReport(findings: findings)
    }

    private func lintFindings() throws -> [AuditFinding] {
        let result = try runner.run(["swiftlint", "lint", "--reporter", "json", "--quiet"], cwd: repoRoot)
        let data = Data(result.stdout.utf8)
        guard !data.isEmpty else { return [] }
        return (try? SwiftLintJSON.findings(fromJSON: data, repoRoot: repoRoot.path)) ?? []
    }

    private func formatDriftFindings() throws -> [AuditFinding] {
        let result = try runner.run(["swiftformat", "--lint", "."], cwd: repoRoot)
        if result.succeeded { return [] }
        let prefix = repoRoot.path.hasSuffix("/") ? repoRoot.path : repoRoot.path + "/"
        // Each drift line starts with a file path; collect distinct files.
        let files = Set(result.stderr.split(separator: "\n").compactMap { line -> String? in
            guard let path = line.split(separator: ":").first.map(String.init), path.hasSuffix(".swift") else {
                return nil
            }
            return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
        })
        return files.sorted().map { file in
            AuditFinding(severity: .low, file: file, line: nil, ruleID: "swiftformat",
                         title: "Formatting drift", detail: "File is not SwiftFormat-clean.",
                         fix: "Run `gate format --fix` (or `swiftformat .`).")
        }
    }

    private func noTestFindings() -> [AuditFinding] {
        let resolver = ScopeResolver(config: config, runner: runner, finder: finder, repoRoot: repoRoot)
        return resolver.allScreens()
            .filter { $0.unitTestClasses.isEmpty && $0.uiTestClasses.isEmpty }
            .map { screen in
                AuditFinding(severity: .high, file: screen.codePath, line: nil, ruleID: "no_tests",
                             title: "Screen has no tests", detail: "Screen \(screen.name) has no unit or UI tests.",
                             fix: "Add \(screen.name)…Tests (unit) and a \(screen.name)UITests flow.")
            }
    }
}
```
> Note: `ScopeResolver.screen(named:)` runs `git`-free discovery via the finder, so `allScreens()` works against the fakes. The Auditor reuses `runner` for both swiftlint and (indirectly) any resolver git calls; `allScreens()` does NOT shell to git.

- [ ] **Step 4: Run, expect PASS.** **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Audit/Auditor.swift Tooling/Tests/GateKitTests/AuditorTests.swift
git commit -m "feat(audit): add Auditor aggregating lint, format drift, no-tests

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `AuditRenderer` — Markdown + GitHub annotations

**Files:** Create `Tooling/Sources/GateKit/Audit/AuditRenderer.swift`, `Tooling/Tests/GateKitTests/AuditRendererTests.swift`.

- [ ] **Step 1: Failing test**

`AuditRendererTests.swift`:
```swift
import Testing
@testable import GateKit

private func sampleReport() -> AuditReport {
    AuditReport(findings: [
        AuditFinding(severity: .critical, file: "App/AView.swift", line: 2, ruleID: "force_try",
                     title: "Force Try", detail: "Force tries should be avoided", fix: "use try/catch"),
        AuditFinding(severity: .low, file: "App/BModel.swift", line: nil, ruleID: "swiftformat",
                     title: "Formatting drift", detail: "Not SwiftFormat-clean.", fix: "run gate format --fix")
    ])
}

@Test func markdownGroupsBySeverityWithHealthAndTopN() {
    let md = AuditRenderer.markdown(sampleReport(), topN: 5)
    #expect(md.contains("Health: 84/100"))         // 100 - 15 - 1
    #expect(md.contains("## Critical"))
    #expect(md.contains("## Low"))
    #expect(md.contains("App/AView.swift:2"))
    #expect(md.contains("force_try"))
    #expect(md.contains("Fix these first"))         // top-N section
}

@Test func githubAnnotationsUseErrorForHighPlusAndWarningBelow() {
    let lines = AuditRenderer.githubAnnotations(sampleReport())
    #expect(lines.contains { $0.hasPrefix("::error file=App/AView.swift,line=2") })   // critical → error
    #expect(lines.contains { $0.hasPrefix("::warning file=App/BModel.swift") })       // low → warning
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`AuditRenderer.swift`:
```swift
/// Renders an `AuditReport` to Markdown and GitHub Actions annotation lines.
public enum AuditRenderer {
    public static func markdown(_ report: AuditReport, topN: Int) -> String {
        var out = "# Gate Audit Report\n\n"
        out += "**Health: \(report.healthScore)/100** — \(report.findings.count) finding(s)\n\n"

        let top = report.topN(topN)
        if !top.isEmpty {
            out += "## Fix these first\n\n"
            for finding in top {
                out += "1. **[\(finding.severity.label)]** `\(location(finding))` — \(finding.title)\n"
            }
            out += "\n"
        }

        for severity in [AuditSeverity.critical, .high, .medium, .low] {
            let items = report.grouped.filter { $0.severity == severity }
            guard !items.isEmpty else { continue }
            out += "## \(severity.label)\n\n"
            for finding in items {
                out += "- `\(location(finding))` — **\(finding.title)** (`\(finding.ruleID)`)\n"
                out += "  - Why: \(finding.detail)\n"
                out += "  - Fix: \(finding.fix)\n"
            }
            out += "\n"
        }
        return out
    }

    public static func githubAnnotations(_ report: AuditReport) -> [String] {
        report.grouped.map { finding in
            let level = finding.severity >= .high ? "error" : "warning"
            let lineParam = finding.line.map { ",line=\($0)" } ?? ""
            return "::\(level) file=\(finding.file)\(lineParam),title=\(finding.title)::\(finding.detail)"
        }
    }

    private static func location(_ finding: AuditFinding) -> String {
        finding.line.map { "\(finding.file):\($0)" } ?? finding.file
    }
}
```

- [ ] **Step 4: Run, expect PASS.** **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Audit/AuditRenderer.swift Tooling/Tests/GateKitTests/AuditRendererTests.swift
git commit -m "feat(audit): render audit report as Markdown + GitHub annotations

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Milestone C — config threshold + CLI + CI

### Task 6: `thresholds.health_min` in `GateConfig`

**Files:** Modify `Tooling/Sources/GateKit/Config/GateConfig.swift`, `Tooling/Tests/GateKitTests/GateConfigTests.swift`.

- [ ] **Step 1: Failing test** — add to `GateConfigTests.swift`:
```swift
@Test func parsesOptionalHealthThreshold() throws {
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
    thresholds: { health_min: 80 }
    """
    let config = try GateConfig.parse(yaml)
    #expect(config.thresholds?.healthMin == 80)
}

@Test func thresholdsAreOptional() throws {
    #expect(makeTestConfig().thresholds == nil)
}
```

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** — in `GateConfig.swift`, add the type + property:
```swift
public struct GateThresholds: Codable, Equatable, Sendable {
    public let healthMin: Int

    enum CodingKeys: String, CodingKey {
        case healthMin = "health_min"
    }
}
```
and add `public let thresholds: GateThresholds?` to `GateConfig`'s stored properties + its `CodingKeys` (`case thresholds`). Because the YAML key is the same (`thresholds`), no custom key needed beyond the existing snake_case map. Ensure it's decoded as optional (absent → nil) — `Decodable` synthesises that for an optional `let`.

- [ ] **Step 4: Run, expect PASS** (`swift test --filter GateConfigTests`). **Step 5: Commit**
```bash
git add Tooling/Sources/GateKit/Config/GateConfig.swift Tooling/Tests/GateKitTests/GateConfigTests.swift
git commit -m "feat(audit): add optional thresholds.health_min to gate.yml schema

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `gate audit` CLI command (+ `--fix`, `--report`, `--annotate`, `--enforce`)

**Files:** Create `Tooling/Sources/gate/AuditCommand.swift`; modify `Tooling/Sources/gate/Gate.swift`.

This is CLI wiring (verified by `gate --help` + an end-to-end `./gate audit` run). Keep it a thin shell over `Auditor`/`AuditRenderer`.

- [ ] **Step 1: Implement `AuditCommand.swift`**
```swift
import ArgumentParser
import Foundation
import GateKit

struct AuditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "Scan the repo and emit a prioritized punch-list + health score."
    )
    @Flag(name: .long, help: "Auto-apply the safe fixes (swiftformat + swiftlint --fix).") var fix = false
    @Option(name: .long, help: "Write the Markdown report to this path.") var report = "GATE_REPORT.md"
    @Flag(name: .long, help: "Emit GitHub Actions annotations to stdout.") var annotate = false
    @Flag(name: .long, help: "Exit non-zero if health < thresholds.health_min.") var enforce = false
    @OptionGroup var common: CommonOptions

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let runner = SystemCommandRunner()

        if fix {
            _ = try? runner.run(["swiftformat", "."], cwd: cwd)
            _ = try? runner.run(["swiftlint", "--fix", "--quiet"], cwd: cwd)
        }

        let configURL = URL(fileURLWithPath: common.config, relativeTo: cwd)
        let config = try GateConfig.load(from: configURL)
        let auditor = Auditor(config: config, runner: runner, finder: SystemFileFinder(), repoRoot: cwd)
        let result = try auditor.audit()

        let markdown = AuditRenderer.markdown(result, topN: 10)
        try? markdown.write(toFile: report, atomically: true, encoding: .utf8)

        if annotate {
            for line in AuditRenderer.githubAnnotations(result) { print(line) }
        }
        print("Audit: health \(result.healthScore)/100, \(result.findings.count) finding(s) → \(report)")

        if enforce, let minimum = config.thresholds?.healthMin, result.healthScore < minimum {
            print("✘ health \(result.healthScore) below required \(minimum)")
            throw ExitCode.failure
        }
    }
}
```

- [ ] **Step 2: Register in `Gate.swift`** — append `AuditCommand.self` to the `subcommands:` array.

- [ ] **Step 3: Build + run end-to-end against this repo**

Run:
```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
swift build --package-path Tooling && swift run --package-path Tooling gate --help | grep audit
./gate audit
head -20 GATE_REPORT.md
```
Expected: `--help` lists `audit`; `./gate audit` prints the health line and writes `GATE_REPORT.md`. Since the repo is lint/format-clean, the only findings should be `no_tests` for any screen lacking tests (e.g. `Posts` if it has no UI test, etc.) — i.e. a HIGH health score, not 100 if a screen lacks tests. Confirm the report renders.

- [ ] **Step 4: Ignore the generated report**

Append to `.gitignore`:
```
# gate audit output (regenerated; not committed)
GATE_REPORT.md
```

- [ ] **Step 5: Commit**
```bash
swiftformat Tooling
git add Tooling/Sources/gate/AuditCommand.swift Tooling/Sources/gate/Gate.swift .gitignore
git commit -m "feat(audit): add gate audit CLI (--fix/--report/--annotate/--enforce)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: additive CI audit step

**Files:** Modify `.github/workflows/ci.yml`.

Add a NON-BLOCKING audit job that posts annotations and uploads the report. Existing jobs unchanged.

- [ ] **Step 1: Append a new job** to `ci.yml`:
```yaml
  audit:
    name: Audit (informational)
    if: github.event_name == 'pull_request'
    runs-on: macos-15
    continue-on-error: true        # never blocks a PR (informational, per the standard)
    steps:
      - uses: actions/checkout@v5
      - name: Install SwiftLint & SwiftFormat
        run: brew install swiftlint swiftformat
      - name: gate audit (annotate + report)
        run: ./gate audit --annotate
      - name: Upload GATE_REPORT.md
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: gate-report
          path: GATE_REPORT.md
```

- [ ] **Step 2: Validate** — `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"` → `yaml ok`. Confirm the existing `lint`/`test`/`archive`/`fast-check` jobs are byte-for-byte unchanged (only a new job appended).

- [ ] **Step 3: Commit**
```bash
git add .github/workflows/ci.yml
git commit -m "ci: add informational gate audit job (annotations + report artifact)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of done (Phase 2C)
- `cd Tooling && swift test` green (new audit suites included).
- `./gate audit` runs against this repo, prints a health line, writes `GATE_REPORT.md` (gitignored), and groups findings Critical→Low with file:line + why + fix + a top-N "fix these first".
- Severity mapping is sound (force-unwrap/try!/cast → Critical; other lint errors → High; warnings → Medium; format drift → Low; screens with no tests → High).
- `./gate audit --fix` applies only swiftformat + swiftlint --fix (no logic refactors). `--annotate` emits GitHub annotation lines. `--enforce` fails only when below `thresholds.health_min`.
- CI has a NON-BLOCKING `audit` job (annotations + report artifact); existing jobs semantically unchanged.
- All process/disk access stays behind the `CommandRunner`/`FileFinder` seams (the Auditor is unit-tested with canned JSON).

## Out of scope (later plans / spec deferrals)
- **Structural conformance vs `gate.yml > structure`** — needs the canonical-structure schema (§13, a later "guide" phase); not yet defined.
- **Retain-cycle-prone-closure heuristic** and **precise missing-`@MainActor`** — fragile via regex/process; land with the SwiftSyntax `ArchLint` stage (deferred in Phase 2B). `gate audit` already surfaces force-unwrap/try!/cast and the §10 architectural custom rules via SwiftLint JSON.
- **`gate adopt` calling `audit` as its closing step** — Phase 4 (bootstrap).
