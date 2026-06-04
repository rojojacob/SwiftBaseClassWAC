# Architectural lint (the standard's enforced design rules)

`swiftlint` runs `--strict` everywhere the gate runs (pre-commit, pre-push, the
Xcode lint phase, CI, `gate lint/all/screen/branch`). Beyond style, these rules
enforce the MVVM + layering architecture.

## Layer 1 — stricter standard
Expanded `opt_in_rules` in `.swiftlint.yml` (e.g. `fatal_error_message`,
`implicitly_unwrapped_optional`, `modifier_order`, `redundant_type_annotation`, …).

> **Note on `file_name`:** This rule was evaluated but pruned — it flags the many
> intentionally multi-type files in both the app (`AppTheme.swift`,
> `OnFirstAppear.swift`, `ErrorAlert.swift`, `HTTPStatus.swift`,
> `Codable+RawRepresentable.swift`) and Tooling (`Commands.swift`,
> `StageCommands.swift`, `StampCommands.swift`, `FileReader.swift`,
> `PipelineTests.swift`). The rule's `excluded` option cannot filter by file path
> (only by type-name pattern), so keeping it green would require splitting or
> renaming every intentionally grouped file — not a trivial fix. The screen-naming
> convention is instead documented in the standard and verified by review.

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
