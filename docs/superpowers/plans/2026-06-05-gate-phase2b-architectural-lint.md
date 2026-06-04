# Gate Phase 2B — Stronger, Architectural Lint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the standard's lint *architectural* — a stricter `.swiftlint.yml` (more opt-in rules + a filename convention) plus regex `custom_rules` that enforce the MVVM/layering boundaries, all shipping clean on the existing codebase and automatically enforced by the gate's existing lint stage.

**Architecture:** Pure configuration — no GateKit/Swift code changes. `LintStage` already runs `swiftlint lint --strict` against the repo-root `.swiftlint.yml`, so any rule added here is enforced everywhere the gate runs (pre-commit, pre-push, Xcode lint phase, CI, `gate all/screen/branch`). Layer 1 expands the builtin rule set conservatively (only rules the clean code already satisfies). Layer 2 adds three regex custom rules that match *content present in the wrong file kind* (`no_print`, `view_no_networking`, `viewmodel_no_swiftui`). Two spec rules are deferred to the future SwiftSyntax `ArchLint` stage because regex cannot express them: `viewmodel_mainactor` (an *absence* check) and the precise `{Name}Model/ViewModel/View` `screen_naming` (the realistic `Posts` feature legitimately deviates); the builtin `file_name` rule covers the achievable part of the naming intent.

**Tech Stack:** SwiftLint custom_rules (NSRegularExpression syntax) + builtin opt-in rules, in repo-root `.swiftlint.yml`. Verified with `swiftlint lint` against temp fixtures and the real tree.

**Hard constraints (carried from Phase 1/2A — do not violate):**
- The whole repo (app **and** `Tooling/`) MUST stay `swiftlint --strict`-clean after every task, or pre-commit / pre-push / CI / the Xcode lint phase all break. After each change run `swiftlint lint --strict --quiet` from the repo root and confirm **0 violations**. If a newly-added builtin rule flags existing code, either make the trivial code fix OR drop that one rule — never leave the tree red.
- NEVER `git commit --no-verify`. Commit subjects are Conventional Commits. Every commit ends with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- These changes touch `.swiftlint.yml` (+ a docs file). `.swiftlint.yml`/`.md` are NOT `*.swift`, so the swift pre-commit hook commands skip — commits pass on the config alone.
- Custom-rule `regex` matches file **contents**; `included`/`excluded` are regexes matched against the file **path**. Custom rules cannot assert absence and cannot match filenames.
- Stay on branch `feat/wac-ios-standard`.

**Verified preconditions (already checked — the rules are designed around these):**
- App sources at `SwiftBaseClassWAC/SwiftBaseClassWAC/**`. Tests at `SwiftBaseClassWAC/SwiftBaseClassWACTests/**` + `…UITests/**`. Engine/CLI at `Tooling/Sources/{GateKit,gate}/**`.
- No `*ViewModel.swift` imports SwiftUI; both `CounterViewModel`/`PostsViewModel` are `@MainActor @Observable`. No `print(` anywhere under `SwiftBaseClassWAC/SwiftBaseClassWAC/`. The `gate` CLI (`Tooling/Sources/gate/`) DOES use `print(` legitimately and must stay exempt. App views (`*View.swift`) don't reference `APIClient`/`URLSession`/`Dependencies.live`.
- Current `.swiftlint.yml` (repo root) already has: `disabled_rules: [trailing_whitespace]`; `opt_in_rules` (empty_count, force_unwrapping, explicit_init, first_where, contains_over_filter_count, last_where, sorted_first_last, toggle_bool, redundant_nil_coalescing, closure_spacing, operator_usage_whitespace, vertical_whitespace_closing_braces, multiline_arguments); `analyzer_rules` (unused_declaration, unused_import); `excluded` (.build, **/.build, DerivedData, **/Generated, fastlane, vendor, Pods, Carthage); thresholds for line/type_body/file/function lengths; `identifier_name` (min 2, excluded id/x/y/to/vm); `type_name` (min 3); `reporter: xcode`.

---

## File Structure
- **Modify:** `.swiftlint.yml` (repo root) — the single source of truth for both layers (Tasks 1–4).
- **Create:** `docs/lint-architecture.md` — documents every rule, its rationale (mapped to a practice), and the two deferred-to-ArchLint checks (Task 5).
- No Swift files change. Fixtures are created in a temp dir at test time and deleted — they never enter the repo.

---

## Task 1: Layer 1 — stricter standard (curated opt-in rules + filename convention)

**Files:** Modify `.swiftlint.yml`.

Add builtin opt-in rules that idiomatic, already-clean code satisfies, plus the `file_name` rule (the achievable part of `screen_naming`). Verify the whole tree stays clean; prune any rule that flags.

- [ ] **Step 1: Establish the baseline is green**

Run: `cd /Users/rojo/Documents/SWIFT-BASE-CLASS && swiftlint lint --strict --quiet ; echo "exit=$?"`
Expected: no output, `exit=0` (the tree is clean under the current rules).

- [ ] **Step 2: Add the curated opt-in rules + file_name config**

In `.swiftlint.yml`, extend the `opt_in_rules:` list (keep the existing entries) with:
```yaml
opt_in_rules:
  # ── existing ──
  - empty_count
  - force_unwrapping
  - explicit_init
  - first_where
  - contains_over_filter_count
  - last_where
  - sorted_first_last
  - toggle_bool
  - redundant_nil_coalescing
  - closure_spacing
  - operator_usage_whitespace
  - vertical_whitespace_closing_braces
  - multiline_arguments
  # ── Phase 2B: stricter standard ──
  - file_name                     # filename should match the primary type (achievable screen_naming)
  - fatal_error_message           # fatalError must explain why
  - empty_string                  # `x.isEmpty` not `x == ""`
  - empty_collection_literal      # `x.isEmpty` not `x == []`
  - flatmap_over_map_reduce
  - joined_default_parameter
  - legacy_random
  - lower_acl_than_parent
  - modifier_order                # consistent @MainActor/public/final ordering
  - prefer_self_in_static_references
  - redundant_type_annotation
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call
  - yoda_condition
  - implicitly_unwrapped_optional # no `T!` ivars
  - private_action
  - private_outlet
  - overridden_super_call
  - prohibited_super_call
```
And add a `file_name` config block (the app's `App.swift` entry point and small multi-type files are allowed) near the other rule configs:
```yaml
file_name:
  severity: warning
  excluded:
    - SwiftBaseClassWACApp.swift   # @main entry; type name differs by convention
    - Post.swift                   # Posts feature domain model (file hosts `Post`)
```

- [ ] **Step 3: Verify the tree stays clean; prune flaggers**

Run: `swiftlint lint --strict --quiet ; echo "exit=$?"`
Expected: `exit=0`, no output. If a rule reports violations:
  1. If it's a trivial, correct fix in the flagged file (e.g. add a `fatalError` message), make it.
  2. Otherwise REMOVE just that one opt-in rule from the list (leave a `# omitted: <rule> — flags <file>` comment) and re-run.
Do NOT proceed until `swiftlint lint --strict --quiet` is `exit=0`. Record which rules (if any) you pruned.

- [ ] **Step 4: Confirm the rules are actually active (sanity)**

Run: `swiftlint rules 2>/dev/null | grep -E 'file_name|fatal_error_message|yoda_condition' | head`
Expected: those rows show `enabled in your config | yes`.

- [ ] **Step 5: Commit**

```bash
git add .swiftlint.yml
git commit -m "feat(lint): Phase 2B layer 1 — stricter opt-in rule set + file_name

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Custom rule `no_print` (app-scoped) — use AppLogger

**Files:** Modify `.swiftlint.yml`.

Flag `print(` in **app** sources only (the `gate` CLI and tests may print).

- [ ] **Step 1: Confirm there is no `custom_rules:` block yet, then add it with `no_print`**

Append to `.swiftlint.yml`:
```yaml
custom_rules:
  no_print:
    name: "Use AppLogger, not print"
    included: ".*/SwiftBaseClassWAC/SwiftBaseClassWAC/.*\\.swift"
    regex: "\\bprint\\("
    match_kinds:
      - identifier
    message: "Use AppLogger instead of print() in app code."
    severity: error
```
(`included` restricts to the app target dir — not the CLI under `Tooling/Sources/gate/`, not the app's test dirs which sit beside `SwiftBaseClassWAC/SwiftBaseClassWAC`.)

- [ ] **Step 2: Write the failing fixture test — a violating file IS flagged**

```bash
rm -rf /tmp/lintfix && mkdir -p "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo"
cat > "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo/DemoView.swift" <<'EOF'
struct DemoView {
    func go() {
        print("hello")
    }
}
EOF
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo/DemoView.swift" 2>&1 | grep -c no_print
```
Expected: `1` (or more) — the fixture's `print(` is flagged by `no_print`.

- [ ] **Step 3: Verify NO false positive — the real app + CLI are clean**

```bash
swiftlint lint --strict --quiet ; echo "app+repo exit=$?"
# The CLI legitimately prints and must NOT be flagged:
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" Tooling/Sources/gate 2>&1 | grep -c no_print
```
Expected: `exit=0` (whole repo clean), and `0` no_print hits in the CLI (it's outside `included`).

- [ ] **Step 4: Clean up the fixture**

Run: `rm -rf /tmp/lintfix`

- [ ] **Step 5: Commit**

```bash
git add .swiftlint.yml
git commit -m "feat(lint): add no_print custom rule (app code must use AppLogger)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Custom rule `view_no_networking`

**Files:** Modify `.swiftlint.yml`.

Flag `APIClient` / `URLSession` / `Dependencies.live` referenced in a `*View.swift` (Views must go through a ViewModel).

- [ ] **Step 1: Add the rule under `custom_rules:`**

```yaml
  view_no_networking:
    name: "View has no networking/DI"
    included: ".*View\\.swift"
    excluded: ".*Tests.*"
    regex: "\\b(APIClient|URLSession|Dependencies\\.live)\\b"
    message: "Views must not touch networking or the DI container directly — go through a ViewModel."
    severity: error
```

- [ ] **Step 2: Failing fixture test — a View touching URLSession IS flagged**

```bash
rm -rf /tmp/lintfix && mkdir -p /tmp/lintfix
cat > /tmp/lintfix/BadView.swift <<'EOF'
import SwiftUI
struct BadView: View {
    let session = URLSession.shared
    var body: some View { Text("x") }
}
EOF
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" /tmp/lintfix/BadView.swift 2>&1 | grep -c view_no_networking
```
Expected: `1` (or more).

- [ ] **Step 3: No false positive — real app views are clean**

```bash
swiftlint lint --strict --quiet ; echo "exit=$?"
```
Expected: `exit=0` (the real `*View.swift` files don't reference those symbols).

- [ ] **Step 4: Clean up + commit**

```bash
rm -rf /tmp/lintfix
git add .swiftlint.yml
git commit -m "feat(lint): add view_no_networking custom rule

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Custom rule `viewmodel_no_swiftui`

**Files:** Modify `.swiftlint.yml`.

Flag `import SwiftUI` in a `*ViewModel.swift` (keep view models UI-framework-free).

- [ ] **Step 1: Add the rule under `custom_rules:`**

```yaml
  viewmodel_no_swiftui:
    name: "ViewModel is UI-framework-free"
    included: ".*ViewModel\\.swift"
    excluded: ".*Tests.*"
    regex: "^import +SwiftUI"
    message: "View models must not import SwiftUI — keep presentation logic UI-agnostic (use Observation)."
    severity: error
```

- [ ] **Step 2: Failing fixture test — a ViewModel importing SwiftUI IS flagged**

```bash
rm -rf /tmp/lintfix && mkdir -p /tmp/lintfix
cat > /tmp/lintfix/BadViewModel.swift <<'EOF'
import SwiftUI
final class BadViewModel {}
EOF
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" /tmp/lintfix/BadViewModel.swift 2>&1 | grep -c viewmodel_no_swiftui
```
Expected: `1` (or more).

- [ ] **Step 3: No false positive — real ViewModels are clean**

```bash
swiftlint lint --strict --quiet ; echo "exit=$?"
# Also prove the real ViewModels are scanned and pass:
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" SwiftBaseClassWAC/SwiftBaseClassWAC/Features 2>&1 | grep -c viewmodel_no_swiftui
```
Expected: `exit=0`, and `0` hits (CounterViewModel/PostsViewModel import `Observation`, not SwiftUI).

- [ ] **Step 4: Clean up + commit**

```bash
rm -rf /tmp/lintfix
git add .swiftlint.yml
git commit -m "feat(lint): add viewmodel_no_swiftui custom rule

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: End-to-end verification + rule documentation

**Files:** Create `docs/lint-architecture.md`. (No `.swiftlint.yml` change unless a gap is found.)

- [ ] **Step 1: Full strict lint via swiftlint AND via the gate**

```bash
cd /Users/rojo/Documents/SWIFT-BASE-CLASS
swiftlint lint --strict --quiet ; echo "swiftlint exit=$?"
./gate lint ; echo "gate-lint exit=$?"
```
Expected: both `exit=0`. (`gate lint` proves the custom rules are enforced through the engine's lint command, hence through every binding.)

- [ ] **Step 2: Prove all three custom rules fire together on a combined fixture**

```bash
rm -rf /tmp/lintfix && mkdir -p "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo"
cat > "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo/DemoView.swift" <<'EOF'
struct DemoView {
    let api = URLSession.shared
    func go() { print("x") }
}
EOF
cat > "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo/DemoViewModel.swift" <<'EOF'
import SwiftUI
final class DemoViewModel {}
EOF
swiftlint lint --no-cache --config "$PWD/.swiftlint.yml" "/tmp/lintfix/SwiftBaseClassWAC/SwiftBaseClassWAC/Features/Demo" 2>&1 \
  | grep -oE 'no_print|view_no_networking|viewmodel_no_swiftui' | sort -u
rm -rf /tmp/lintfix
```
Expected output (three lines, any order):
```
no_print
view_no_networking
viewmodel_no_swiftui
```

- [ ] **Step 3: Write `docs/lint-architecture.md`**

```markdown
# Architectural lint (the standard's enforced design rules)

`swiftlint` runs `--strict` everywhere the gate runs (pre-commit, pre-push, the
Xcode lint phase, CI, `gate lint/all/screen/branch`). Beyond style, these rules
enforce the MVVM + layering architecture.

## Layer 1 — stricter standard
Expanded `opt_in_rules` in `.swiftlint.yml` (e.g. `file_name`, `fatal_error_message`,
`implicitly_unwrapped_optional`, `modifier_order`, `redundant_type_annotation`, …).
`file_name` enforces that a file's name matches the primary type it declares — the
achievable part of the "screen naming" convention (`Post.swift` and the `@main`
entry are the documented exceptions).

## Layer 2 — architectural custom rules (`custom_rules` in `.swiftlint.yml`)
| Rule | Severity | Catches | Why |
|---|---|---|---|
| `no_print` | error | `print(` in `SwiftBaseClassWAC/SwiftBaseClassWAC/**` | App code must log via `AppLogger`; the `gate` CLI is exempt by path. |
| `view_no_networking` | error | `APIClient`/`URLSession`/`Dependencies.live` in `*View.swift` | Views render; they must reach data through a ViewModel. |
| `viewmodel_no_swiftui` | error | `import SwiftUI` in `*ViewModel.swift` | View models stay UI-framework-free (use `Observation`). |

## Deferred to the future SwiftSyntax `ArchLint` stage (regex can't express these)
- **`viewmodel_mainactor`** — flagging a `*ViewModel` that is *missing* `@MainActor`/
  `@Observable` is an *absence* check; SwiftLint regex custom rules only match content
  that is present. Needs AST inspection.
- **precise `screen_naming`** (`{Name}Model/ViewModel/View`) — the realistic `Posts`
  feature legitimately uses `Post`, `PostsListView`, `PostDetailView`, so a strict
  regex would false-positive the standard's own code. `file_name` (Layer 1) covers
  the achievable part; the precise convention check needs AST + folder context.

These two land with the `GateKit/Stages/ArchLint` SwiftSyntax stage (a later phase).
```

- [ ] **Step 4: Commit**

```bash
git add docs/lint-architecture.md
git commit -m "docs(lint): document Phase 2B architectural rules + ArchLint deferrals

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of done (Phase 2B)
- `swiftlint lint --strict --quiet` (whole repo, app + `Tooling/`) is **0 violations** with the expanded rule set.
- `./gate lint` exits 0 — the custom rules are enforced through the engine, hence through all four bindings + CI.
- The three custom rules (`no_print`, `view_no_networking`, `viewmodel_no_swiftui`) each demonstrably flag a violating fixture and do NOT flag the existing codebase (CLI `print` stays exempt).
- `docs/lint-architecture.md` documents every rule and the two honest ArchLint deferrals.
- No Swift/engine code changed; the branch stays `swiftlint --strict`-green so no binding breaks.

## Out of scope (later plans)
- **2C — `gate audit`** (industrial punch-list + health score; will *also* report these architectural findings on adoption).
- **SwiftSyntax `ArchLint` stage** carrying `viewmodel_mainactor` + precise `screen_naming` (a later phase, per spec §10's "future extension point").
- Green-compute caching.
