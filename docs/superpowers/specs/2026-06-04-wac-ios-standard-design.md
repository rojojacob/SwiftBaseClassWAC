# WAC iOS Standard — Design Spec

**Status:** Approved (brainstorming complete) · **Date:** 2026-06-04 · **Branch:** `feat/wac-ios-standard`

A reusable iOS engineering standard that turns this repository into three things at once:
a **reference app**, a **scope-aware quality-gate engine**, and a **bootstrapper** that installs
the standard into any other project — built so a human *or* an AI agent can follow and enforce it.

---

## 1. Vision & goals

Today `SwiftBaseClassWAC` is a high-quality SwiftUI reference app with SwiftLint/SwiftFormat,
Lefthook hooks, fastlane release lanes, and a fail-fast CI (`lint → test → archive`). This spec
extends it into a **standard** with six capabilities:

1. **A guide** — one canonical, machine-readable description of "how every action is done in a
   Swift project here," that a developer or an AI can follow.
2. **A scope-aware gate engine** — validate a *single screen*, *several screens*, *a branch's
   diff*, or *everything*, through `format → lint → build → test`, with `archive`/`testflight` as
   deliberate keyword-only stages. A non-passing gate is a hard, blocking failure ("stays stuck"
   until green).
3. **Stronger, architectural lint** — catch real bugs and architecture violations, not just style.
4. **Branch-agnostic, additive CI** — validate on push/PR across branches *without* changing the
   behavior of the CI that already works.
5. **A bootstrapper** — `gate init <url>` scaffolds a new project on the standard; `gate adopt
   <url>` retrofits the standard onto an existing one, and on integration **immediately points at
   the code/areas/functions to fix** at an industrial best-practice level.
6. **An AI contract** — `CLAUDE.md` / `AGENTS.md` + committed Claude Code commands and a
   code-reviewer agent, so the AI workflow ships with the repo.

### Non-goals (YAGNI for v1)

- A full SwiftSyntax-based semantic linter (regex custom rules + heuristics are enough for v1; a
  SwiftSyntax `ArchLint` stage is a documented future extension point).
- Auto-refactoring of business logic. The engine auto-fixes only deterministic-safe classes
  (formatting, trivially-mechanical lint); everything else becomes a report item.
- Android/multiplatform. iOS/Xcode only.
- Replacing fastlane. `archive`/`testflight` delegate to the existing fastlane lanes.

---

## 2. Locked decisions

These were settled during brainstorming and are fixed inputs to the design:

| Decision | Choice |
|---|---|
| Engine substrate | **Swift package** (`Tooling/`) building a `gate` CLI via ArgumentParser; logic in a `GateKit` library, unit-tested with Swift Testing (dogfoods the app's own stack). |
| Scope mapping | **Naming convention** — a screen's folder name maps deterministically to its code + unit + UI tests. |
| Enforcement bindings | **All four:** pre-commit (scoped, fast), pre-push (scoped, full), an Xcode build phase, and CI. |
| Bootstrap modes | **Both** `init` (new repo) and `adopt` (existing repo). |
| Archive/TestFlight trigger | **CLI command** (`gate archive`, `gate testflight`); never in the automatic pipeline. |
| Lint strength | **Architectural enforcement** — stricter standard rules + custom rules encoding the architecture. |
| AI integration | **Docs + committed commands** — `CLAUDE.md`/`AGENTS.md` + `.claude/commands/` + a code-reviewer agent. |
| "Ecofriendly" | **Green compute** — never run a stage whose inputs can be proven unchanged; cache aggressively; measure savings. |
| CI changes | **Additive only** — existing jobs keep their exact semantics; enhancements layer on top, separable and reversible. |

---

## 3. Glossary

- **Screen** — a feature folder `Features/<Name>/`. The atomic unit of scoping. May contain
  multiple views (e.g. `PostsListView`, `PostDetailView`) but is gated as one unit.
- **Scope** — what a gate run targets: `screen`, `screens`, `branch` (diff-derived), or `all`.
- **Stage** — one step in the pipeline: `format`, `lint`, `build`, `test`, `archive`, `testflight`,
  `audit`, `verify-stamp`.
- **Gate** — a scoped run of the ordered stages, fail-fast.
- **Stamp** — `.gate/last-green.json`, a per-screen content hash recorded on a passing run; powers
  both the "stuck until green" build phase and the green-compute "skip unchanged" cache.
- **`gate.yml`** — the single source of truth for project parameters, conventions, structure rules,
  and thresholds. Makes the engine dynamic (not hardcoded to this app).

---

## 4. Guiding principles

1. **One engine, many callers.** Pre-commit, pre-push, the Xcode build phase, CI, the developer,
   and the AI all invoke the *same* `gate` binary. No rule is defined twice.
2. **Green compute.** Never run a stage you can prove is unnecessary. Scope by default, cache
   aggressively, skip on unchanged inputs, and measure what was saved.
3. **Document *and* enforce.** Every rule in the guide has a corresponding check in the engine.
   Prose that isn't enforced is a future lie; a check without prose is unexplained friction.
4. **Fail loud, fail early, fail cheap.** Cheapest checks first (format → lint → build → test); the
   first failure stops the run with an actionable message.
5. **Additive over destructive.** Never break what works (CI, the app, an adopted repo's code).
   Enhance alongside; back up before overwriting; prefer PRs over force-pushes.
6. **Isolation & testability.** The engine's logic is pure and unit-tested; all shell/process access
   sits behind a mockable seam so tests don't shell out.

---

## 5. Repository restructure — four zones

The app folder stays where it is (renaming the Xcode project is high-risk churn for no benefit). We
*add* three zones so the repo's four roles are unambiguous:

```
SWIFT-BASE-CLASS/
  SwiftBaseClassWAC/                 # ZONE 1 — the reference app (existing architecture, unchanged)
    SwiftBaseClassWAC.xcodeproj
    Config/                          #   per-environment xcconfig + Info.plist
    SwiftBaseClassWAC/               #   app sources (App/, Features/, Core/, DesignSystem/, Resources/)
    SwiftBaseClassWACTests/          #   unit tests (Swift Testing)
    SwiftBaseClassWACUITests/        #   UI tests (XCUITest)

  Tooling/                           # ZONE 2 — the Swift package that builds `gate`
    Package.swift
    Sources/
      gate/                          #   executable target (ArgumentParser): Commands/*
      GateKit/                       #   library target (pure, unit-tested):
        Config/                      #     gate.yml loader + schema
        Scope/                       #     scope resolution (naming convention, git-diff)
        Shell/                       #     CommandRunner seam (mockable process execution)
        Stages/                      #     Stage protocol + Format/Lint/Build/Test/Archive/TestFlight/Audit
        Pipeline/                    #     ordered fail-fast runner + Report + Stamp + Eco ledger
        Audit/                       #     findings model, severity, health score, GATE_REPORT renderer
        Bootstrap/                   #     ProjectClassifier + template renderer (init/adopt)
    Tests/GateKitTests/              #   Swift Testing unit tests for the engine

  templates/                         # ZONE 3 — placeholder files the bootstrapper renders into targets
    gate.yml.tmpl  .swiftlint.yml.tmpl  lefthook.yml.tmpl  ci.yml.tmpl  CLAUDE.md.tmpl  …

  docs/                              # ZONE 4 — the human + AI guide
    ARCHITECTURE.md                  #   the canonical structure + rules (the "law")
    GATE.md                          #   gate engine reference
    patterns/                        #   one playbook per action (see §13)
    superpowers/specs/               #   design specs (this file)
  CLAUDE.md  AGENTS.md               # AI contract (root)
  .claude/commands/  .claude/agents/ # committed Claude Code commands + code-reviewer agent

  gate                               # thin wrapper → `swift run --package-path Tooling gate "$@"`
  gate.yml                           # project config (single source of truth)
  .swiftlint.yml + Rules/            # stronger lint + custom architectural rules
  .swiftformat  lefthook.yml  Brewfile  …   # existing tooling (enhanced, not replaced)
```

The existing `scripts/` (`preflight.sh`, `scaffold-feature.sh`, …) are superseded by `gate`
subcommands and become thin shims that call `gate` (kept for muscle-memory; documented as
deprecated aliases).

---

## 6. The gate engine (`GateKit`)

### 6.1 Core types

```
protocol CommandRunner {                     // the only door to the outside world (mockable)
    func run(_ argv: [String], cwd: URL, env: [String:String]) throws -> ProcessResult
}

protocol Stage {
    var id: StageID { get }                  // .format .lint .build .test .archive .testflight .audit
    func run(_ scope: ResolvedScope, _ ctx: GateContext) throws -> StageResult
}

struct ResolvedScope { let kind: ScopeKind; let screens: [Screen]; let files: [URL] }
struct StageResult  { let stage: StageID; let outcome: Outcome; let findings: [Finding]; let duration; let skipped: Bool; let cacheHit: Bool }
struct Report       { let results: [StageResult]; var passed: Bool; let eco: EcoLedger }
```

- `GateContext` carries the loaded `gate.yml`, the `CommandRunner`, the repo root, and logging.
- The **Pipeline** runs stages in fixed order, **fail-fast**: first non-passing stage stops the run
  and returns a `Report` with a non-zero process exit. The blocking exit code *is* the "stays stuck"
  mechanism every binding relies on.
- All process execution goes through `CommandRunner`; `GateKitTests` injects a fake runner, so the
  engine's branching/scoping/reporting is unit-tested without invoking `xcodebuild`.

### 6.2 Command surface (`Sources/gate/Commands`)

```
gate screen <Name> [--ui|--no-ui] [--archive] [--testflight]   # one screen
gate screens <A> <B> …                                         # several screens
gate branch [--base main]                                      # git diff → only affected screens
gate all                                                       # whole repo (replaces preflight.sh)
gate lint [scope]            gate format [--fix]               # single stages
gate audit [--fix] [--report GATE_REPORT.md] [--annotate]      # industrial punch-list (§12)
gate verify-stamp                                              # build-phase guard (§9)
gate archive                                                   # unsigned .xcarchive  (keyword stage)
gate testflight                                                # signed build + upload (fastlane beta)
gate scaffold-screen <Name>                                    # replaces scaffold-feature.sh
gate init <git-url>  --name X --bundle-id Y                    # NEW project → push
gate adopt <git-url>                                           # retrofit / generate → PR (§14)
gate doctor                                                    # verify toolchain (xcode, swiftlint, …)
```

Global flags: `--config <path>` (default `gate.yml`), `--json` (machine-readable report),
`--no-cache` (force full run), `--quiet/--verbose`.

---

## 7. `gate.yml` — the single source of truth

Makes the engine dynamic and portable; written by `init`/`adopt` for each target project.

```yaml
project:   SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj
scheme:    SwiftBaseClassWAC
targets:
  app:  SwiftBaseClassWAC
  unit: SwiftBaseClassWACTests
  ui:   SwiftBaseClassWACUITests
simulator: "iPhone 16"
base_branch: main

conventions:                 # how scope maps to files (drives §8 + audit + lint)
  features_dir: SwiftBaseClassWAC/SwiftBaseClassWAC/Features
  unit_glob:    "SwiftBaseClassWACTests/**/{Name}*Tests.swift"
  ui_class:     "{Name}UITests"
  shared_dirs:  [Core, DesignSystem]      # change here → escalate to `all`

structure:                   # the enforced layout contract (audit checks against this)
  screen_files: ["{Name}Model.swift", "{Name}ViewModel.swift", "{Name}View.swift"]
  require_test_per_screen: true

stages: [format, lint, build, test]        # the default pipeline (archive/testflight excluded)

thresholds:                  # surfaced in audit + lint
  health_min: 80
  file_length: { warning: 400, error: 700 }

eco:
  cache: [swiftpm, deriveddata, swiftlint]
  ledger: .gate/eco.json
```

---

## 8. Scope resolution (naming convention)

Screen `Posts` owns — by convention encoded in `gate.yml`:

- **code** → `Features/Posts/**`
- **unit** → `…Tests/**/Posts*Tests.swift`
- **UI** → `…UITests/PostsUITests` (XCUITest `-only-testing:`)

| Command | Resolution |
|---|---|
| `gate screen Posts` | lint the screen's files + `xcodebuild test -only-testing:…/PostsViewModelTests -only-testing:…/PostsUITests` |
| `gate screens Posts Counter` | union of both screens |
| `gate branch --base main` | `git diff --name-only main...HEAD` → map each path to its owning screen; a path under a `shared_dir` escalates the whole run to `all` |
| `gate all` | every screen + repo-wide lint/format/build |

The convention is **enforced** by the `screen_naming` custom lint rule and by `gate scaffold-screen`,
so scoping can never silently miss a test. If a screen has no tests and `require_test_per_screen` is
true, the gate **fails** with "Posts has no tests."

---

## 9. The "stuck until green" mechanism

Three of the four bindings (pre-commit, pre-push, CI) simply rely on the **blocking non-zero exit**
of a failed gate. The fourth — the Xcode build phase — uses a **verification stamp** instead of
running tests inside the build (which would be recursive and slow):

1. On every passing run, `gate` writes `.gate/last-green.json` = `{ "Posts": "<sha>", … }`, a content
   hash per screen (hash of the screen's source + its tests).
2. The Xcode build phase runs **`gate verify-stamp`** (milliseconds): for each screen, compare the
   current source hash to the stamped hash. Any mismatch → **the build fails** with:
   `✘ Posts changed since last green gate — run 'gate screen Posts'`.
3. Flow: edit a screen → ⌘R fails → run `gate screen Posts` → it passes and re-stamps → ⌘R builds.

This delivers the literal requirement ("after a screen, the project won't run until its tests pass"),
per-screen, fast, and without recursion. The same hashes are the green-compute cache key (§11).

> Escape hatch: `GATE_SKIP_STAMP=1` (e.g. for a clean checkout / first run) skips the guard with a
> printed warning, so a fresh clone is never wedged.

---

## 10. Stronger, architectural lint (subsystem D)

Two layers:

**Layer 1 — stricter standard.** Expand `.swiftlint.yml`: more `opt_in_rules`, keep `analyzer_rules`,
tighten complexity/length thresholds, enable `strict` everywhere.

**Layer 2 — custom architectural rules** (regex-based, single-module-friendly, in `.swiftlint.yml`
`custom_rules` + `Rules/`):

| Rule | Catches |
|---|---|
| `view_no_networking` | `APIClient` / `URLSession` / `Dependencies.live` referenced in `*View.swift` |
| `viewmodel_mainactor` | `*ViewModel.swift` missing `@MainActor` and/or `@Observable` |
| `viewmodel_no_swiftui` | `*ViewModel.swift` that `import SwiftUI` (keep view models UI-framework-free) |
| `no_print` | `print(` anywhere — must use `AppLogger` |
| `screen_naming` | files under `Features/<X>/` whose names violate the `{Name}Model/ViewModel/View` convention |

Future extension point (out of scope v1): a SwiftSyntax-based `ArchLint` stage in `GateKit/Stages`
for checks regex can't express precisely.

---

## 11. Green compute (subsystem: ecofriendly)

The rule: **never run a stage whose inputs can be proven unchanged.**

- **Scope by default** — `gate branch` runs only affected screens; CI uses it for PRs.
- **Skip-on-unchanged** — `gate screen X` short-circuits to exit 0 if X's current hash == its
  last-green stamp. "Nothing changed" → zero compute. `--no-cache` forces a full run.
- **Layer caching in CI** — SwiftPM (`~/Library/Caches/org.swift.swiftpm`, `.build`), DerivedData,
  and SwiftLint caches (additive; identical outcomes, less time/energy).
- **Fail-fast ordering + cancel-in-progress** — already in CI; kept and leaned on.
- **The Eco ledger** — every run prints `stages skipped · cache hits · ~CI-minutes saved` and appends
  to `.gate/eco.json`, so "ecofriendly" is a measurable number, not a claim.

---

## 12. `gate audit` — the industrial-grade punch-list (subsystem: "point at what to fix")

A standalone command **and** the closing step of `gate adopt`. It scans the project and produces a
prioritized, code-pointing report.

- **Scans:** all SwiftLint rules (incl. the §10 custom rules), SwiftFormat drift, force-unwraps,
  missing `@MainActor`, screens with no tests, layering violations, oversized types/functions,
  retain-cycle-prone closures (heuristic), structural conformance vs. `gate.yml > structure`.
- **Output `GATE_REPORT.md`** — grouped **Critical → High → Medium → Low**; each finding =
  `file:line`, the **type/func**, the rule, the *why* (mapped to a recognized practice), and the fix.
- **Health score 0–100** + a top-N "fix these first" list. Fails CI only if below `thresholds.health_min`
  *and* run with `--enforce` (default in CI is **non-blocking/informational**, per §5).
- **In CI** — emits inline **GitHub annotations** so findings appear on the code, and uploads the
  report as an artifact.
- **`--fix`** — auto-applies only the deterministic-safe class (formatting, trivially-mechanical
  lint). Never refactors logic; those remain report items for a human or the AI.

---

## 13. Canonical structure + per-action playbooks (the "guide")

- **`docs/ARCHITECTURE.md`** — the canonical tree + the rules (the law), mirroring `gate.yml >
  structure` so doc and enforcement agree.
- **`docs/patterns/`** — one playbook per action, each in the same shape:
  **When · Where it goes · Steps · Template · Required test · Which gate proves it.**

  ```
  add-a-screen · add-networking-endpoint · add-a-model · dependency-injection
  error-handling · persistence · navigation · validation · logging
  design-system-component · writing-tests · adding-an-SPM-dependency · environments
  ```

- The structure is **machine-readable** in `gate.yml > structure` and validated by `gate audit` +
  the `screen_naming` lint rule, so the documented pattern is also the enforced pattern.
- `gate scaffold-screen` generates straight from the `add-a-screen` playbook (Model + ViewModel +
  View + a unit test stub + a UI test stub), preserving the convention scope depends on.

---

## 14. Bootstrap: `init`, `adopt`, and the bare-project classifier (subsystems B + "auto-create")

### 14.1 `gate init <git-url> --name NewApp --bundle-id com.x.NewApp`

1. Render `templates/` with the placeholders (`__APP_NAME__`, `__BUNDLE_ID__`, …) into a working dir.
2. Rename `SwiftBaseClassWAC → NewApp` across the pbxproj, folders, schemes, and configs.
3. Wire hooks (`lefthook install`), copy `Tooling/`, `.swiftlint.yml`, CI, `CLAUDE.md`, `gate.yml`.
4. `git init`, set remote to `<git-url>`, initial commit, push.

### 14.2 `gate adopt <git-url>` — classify, then act

A **`ProjectClassifier`** inspects the cloned repo → `bare` / `partial` / `established`:

- **bare** — no `.xcodeproj`, or a stock single-`ContentView` skeleton with "no real valid files":
  → **generate the full standard itself** by rendering the same template `init` uses *into that
  repo* (app sources, `Core/`, `DesignSystem/`, a sample screen, tests, configs). *Create your own
  method and files automatically.*
- **partial / established** — real code present: → **retrofit non-destructively** (add lint, hooks,
  `Tooling/`, CI, `CLAUDE.md`; back up any file it would overwrite), then run **`gate audit`** so
  integration immediately points at the areas/code/functions to fix.
- In all cases adopt **opens a PR** ("Adopt WAC iOS standard") rather than pushing to a default
  branch — never force-overwrites the target's history.

---

## 15. Enforcement bindings (all four call `gate`)

| Binding | Runs | Notes |
|---|---|---|
| **pre-commit** (lefthook) | `gate format --fix` + lint + scoped **unit** tests for changed screens | UI tests excluded here to stay fast |
| **pre-push** (lefthook) | `gate branch` (affected screens, unit **+ UI**) | last line before code leaves the machine |
| **Xcode build phase** | `gate verify-stamp` (§9) | milliseconds; `GATE_SKIP_STAMP=1` escape hatch |
| **CI** | `gate all` / `gate branch` + non-blocking `gate audit` | required checks `Lint`, `Build & Test` |

Existing lefthook hooks are rewritten to call `gate` (no behavior loss — same lint/format, plus the
new scoped tests).

---

## 16. CI enhancement — additive only (subsystem E)

The existing `lint → test → archive` jobs and the manual `testflight.yml` **keep their exact
semantics.** Enhancements layer on top, each separable and reversible:

- **+ caching** — SwiftPM / DerivedData / SwiftLint (faster, greener, identical results).
- **+ `gate audit` step** — uploads `GATE_REPORT.md` + posts annotations; **non-blocking** (won't
  fail a build that passes today).
- **+ a green/scoped fast-check** — a *new* job running `gate branch` for PRs; the existing full
  `test` job remains the source of truth.
- **+ broader branch coverage** — additive triggers so feature branches *also* get CI; existing
  branches behave identically.

No existing step changes meaning; nothing green today goes red because of this change. The CI jobs
invoke `gate` so CI and local enforcement cannot drift.

---

## 17. AI contract (subsystem F)

- **`CLAUDE.md`** (root, auto-loaded by Claude Code) — the rules, the architecture in brief, how to
  run the gate, and the **definition of done: `gate` is green**. Concise; links to `docs/`.
- **`AGENTS.md`** — vendor-neutral mirror for other agents.
- **`docs/ARCHITECTURE.md`, `docs/GATE.md`, `docs/patterns/`** — the deep references.
- **`.claude/commands/`** — `/scaffold-screen`, `/gate`, `/ship-testflight`, `/adopt`.
- **`.claude/agents/code-reviewer.md`** — a subagent pre-loaded with the standard, used by
  `gate audit` narratives and PR review.
- The same **`gate.yml`** is the machine-readable contract both the engine and the AI read.

---

## 18. Error handling

- Every `gate` failure prints a single actionable line (`✘ <stage>: <what> — <how to fix>`) and exits
  non-zero. `--json` emits the structured `Report` for tooling/AI.
- Missing toolchain (swiftlint, xcodebuild, fastlane) → `gate doctor` diagnoses; commands fail early
  with install hints (`brew bundle`).
- Bootstrap is transactional: render into a temp dir, validate, then move/commit; on any error it
  cleans up and never leaves a half-written target.
- Adopt backs up any file it would overwrite to `*.bak` and lists them in the PR body.

---

## 19. Testing strategy (for the engine itself)

- `GateKitTests` (Swift Testing) injects a fake `CommandRunner` to test scope resolution, the
  fail-fast pipeline, stamp hashing/skip logic, the eco ledger math, audit severity/health scoring,
  and the bootstrap classifier — **without** shelling out to `xcodebuild`.
- A small set of integration tests run real `gate all` / `gate screen` against this repo in CI.
- The engine is itself gated: `Tooling/` is linted and tested by the same pipeline it powers.

---

## 20. Build order (each is its own spec → plan → implement cycle)

1. **Phase 1 — Engine keystone:** `Tooling/` package, `gate.yml` loader, `CommandRunner` seam, scope
   resolution, the fail-fast Pipeline, and `gate all` / `gate screen` / `gate branch`. Unit-tested.
2. **Phase 2 — Enforcement & strength:** the stamp + `gate verify-stamp` + Xcode build phase, the
   four bindings, the stronger/architectural lint, green caching, additive CI, and `gate audit`.
3. **Phase 3 — Release stages:** `gate archive` / `gate testflight` delegating to fastlane.
4. **Phase 4 — Bootstrap:** `templates/`, the renderer, `ProjectClassifier`, `gate init` / `gate adopt`
   (incl. bare-project generation).
5. **Phase 5 — The guide & AI contract:** `docs/ARCHITECTURE.md`, `docs/patterns/` playbooks,
   `CLAUDE.md` / `AGENTS.md`, `.claude/commands/` + code-reviewer agent.

Phase 1 is the keystone; every later phase plugs into the same engine.

---

## 21. Risks & open questions

- **Xcode build-phase friction** — the stamp guard adds a step to ⌘R. Mitigated by being
  millisecond-fast and the `GATE_SKIP_STAMP` hatch. Revisit if it annoys in practice.
- **`gate init` pbxproj rewriting** — renaming across `project.pbxproj` is fiddly; template rendering
  + targeted string replacement (the approach already proven in this repo's own rename) keeps it
  reliable, but it's the riskiest bootstrap code and needs solid tests.
- **Custom-rule false positives** — regex architectural rules can over-match; thresholds and
  `// gate:disable <rule>` inline escapes are provided, and rules ship `warning` first, promoted to
  `error` once proven.
- **`swift run` cold-build latency** in hooks/CI — mitigated by building `gate` once and caching the
  `.build` artifact; CI builds the tool in a cached step.
