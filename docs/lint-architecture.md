# Architectural lint (the standard's enforced design rules)

`swiftlint` runs `--strict` everywhere the gate runs (pre-commit, pre-push, the
Xcode lint phase, CI, `gate lint/all/screen/branch`). Beyond style, these rules
enforce the MVVM + layering architecture.

## Layer 1 — stricter standard
Expanded `opt_in_rules` in `.swiftlint.yml` (e.g. `fatal_error_message`,
`implicitly_unwrapped_optional`, `modifier_order`, `redundant_type_annotation`, …),
plus **`file_name`** — every Swift file's name must match the primary type it
declares (so `CounterView.swift` declares `CounterView`). This is the achievable,
filename-level half of the screen-naming convention.

> **`file_name` exemptions:** intentionally multi-type / extension files are exempt
> via `file_name.excluded` (app: `AppTheme.swift`, `OnFirstAppear.swift`,
> `ErrorAlert.swift`, `HTTPStatus.swift`, `Codable+RawRepresentable.swift`,
> `XCUIHelpers.swift`) and `file_name.excluded_paths` (`Tooling/`, the gate engine,
> which groups types per file by design). Feature files (`*View`/`*ViewModel`/`*Model`
> and domain models) are NOT exempt, so the rule enforces the convention where it
> matters.

## Layer 2 — architectural custom rules (`custom_rules` in `.swiftlint.yml`)
| Rule | Severity | Catches | Why |
|---|---|---|---|
| `no_print` | error | `print(`/`debugPrint(` (identifier kind only) in `SwiftBaseClassWAC/SwiftBaseClassWAC/**` | App code must log via `AppLogger`; the `gate` CLI is exempt by path. |
| `view_no_networking` | error | `APIClient`/`URLSession`/`Dependencies.live` in `*View.swift` | Views render; they must reach data through a ViewModel. |
| `viewmodel_no_swiftui` | error | `import SwiftUI` in `*ViewModel.swift` | View models stay UI-framework-free (use `Observation`). |

## Deferred to the future SwiftSyntax `ArchLint` stage (regex can't express these)
- **`viewmodel_mainactor`** — flagging a `*ViewModel` that is *missing* `@MainActor`/
  `@Observable` is an *absence* check; SwiftLint regex custom rules only match content
  that is present. Needs AST inspection.
- **precise `screen_naming`** (`{Name}Model/ViewModel/View` per feature folder) — the
  realistic `Posts` feature legitimately uses `Post`, `PostsListView`, `PostDetailView`,
  so a strict regex would false-positive the standard's own code. The builtin
  `file_name` rule (Layer 1) enforces the achievable filename↔type half; the precise
  per-screen convention check needs AST + folder context.

These two land with the `GateKit/Stages/ArchLint` SwiftSyntax stage (a later phase).
