# SwiftBaseClassWAC

A SwiftUI app skeleton wired for quality from commit one: SwiftLint + SwiftFormat,
a Lefthook pre-commit gate, an MVVM sample feature with unit + UI tests, and a
fail-fast CI/CD pipeline. Built to mirror the full iOS release pipeline.

- **Min iOS:** 17.0 (enables the `@Observable` macro)
- **Language:** Swift 5 mode (Xcode 26)
- **Architecture:** MVVM with `@Observable` view models
- **Bundle ID:** `com.wac.SwiftBaseClassWAC`

---

## Project layout

```
SwiftBaseClassWAC/
  SwiftBaseClassWAC.xcodeproj
  Config/                          # xcconfig per environment + partial Info.plist
  SwiftBaseClassWAC/            # app target (synchronized folder group)
    App/                           # entry point, RootView, Navigation/Router
    Features/                      # one folder per feature (View+ViewModel+Model)
      Counter/                     #   local-state MVVM sample
      Posts/                       #   networked sample (APIClient + Router)
    Core/
      Networking/                  #   Endpoint, HTTPClient, interceptors, APIClient, APIError
      DependencyInjection/         #   Dependencies container (environment-injected)
      Persistence/                 #   KeychainStore + @AppStorage Codable bridge
      Configuration/               #   AppConfiguration / AppEnvironment
      Validation/                  #   ValidationRule
      Logging/                     #   OSLog AppLogger
    DesignSystem/                  # tokens + components (AsyncButton, ValidatedTextField) + modifiers
    Resources/                     # Assets.xcassets
  SwiftBaseClassWACTests/       # unit tests (Swift Testing) + Mocks/fixtures
  SwiftBaseClassWACUITests/     # UI tests (XCUITest) + page-object helpers
scripts/                           # preflight, feature scaffolder, shared helpers
.github/workflows/                 # CI (lint→test→archive) + manual TestFlight
fastlane/                          # signing (match) + TestFlight + App Store lanes
Brewfile  .swiftlint.yml  .swiftformat  lefthook.yml  .editorconfig
```

> **Note on test folders:** Xcode synchronized groups mean source files are
> auto-discovered — just drop a `.swift` file in any folder under the app target
> and it compiles. Test *targets* must live in their own sibling folders
> (`…Tests` / `…UITests`), which is why they sit outside the app folder rather
> than in a nested `Tests/` directory.

---

## Architecture & building blocks

- **MVVM + `@Observable`** view models; **constructor injection** with a live
  default (`Dependencies.live.*`) so views are zero-config and tests pass mocks.
- **Networking** (`Core/Networking`): build an `Endpoint`, hand it to `APIClient`
  → it applies `RequestInterceptor`s (e.g. bearer token), sends over the
  `HTTPClient` seam (mockable), validates the status, and decodes. `APIError`
  carries the server error body; `MockURLProtocol` makes it all unit-testable.
- **Dependency container** (`Dependencies`) injected via the SwiftUI environment.
- **Persistence:** `KeychainStore` for secrets (tokens); `@AppStorage` works with
  `Codable` collections via the `RawRepresentable` bridge.
- **Navigation:** a `Router` drives a `NavigationStack`; features are routes.
- **Toolkit:** `.onFirstAppear`, `AsyncButton`, `ValidatedTextField` +
  `ValidationRule`, `.errorAlert`, and the design-system tokens/components.
- **Config:** `AppConfiguration` / `AppEnvironment` read per-environment values
  (see Environments below).

Scaffold a new feature (Model + ViewModel + View + test) in one command:

```bash
./scripts/scaffold-feature.sh Profile
```

## Environments

Per-environment values live in `Config/*.xcconfig` and are merged into the
generated Info.plist via the partial `Config/Info.plist`, then read by
`AppConfiguration.current`:

| Build configuration | xcconfig | `API_BASE_URL` | `APP_ENVIRONMENT` |
|---------------------|----------|----------------|-------------------|
| Debug | `Development.xcconfig` | jsonplaceholder.typicode.com | development |
| Release | `Production.xcconfig` | api.example.com | production |

To add **Staging**: in Xcode → *Project ▸ Info ▸ Configurations*, duplicate
Release as `Staging` and set its config file to `Config/Staging.xcconfig`.
Secrets go in `Config/Secrets.xcconfig` (gitignored; copy from `Secrets.example.xcconfig`).

---

## First-time setup

```bash
brew bundle        # swiftlint, swiftformat, lefthook, xcbeautify (see Brewfile)
lefthook install   # git hooks: pre-commit (format+lint), commit-msg, pre-push
bundle install     # (optional) fastlane for signing/distribution
```

Open `SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj`, then **⌘R** to run and
**⌘U** to test. Before pushing, run **`./scripts/preflight.sh`** (the same gate as CI).

---

## Quality gates — where each one lives

| Gate         | Local           | Pre-commit     | CI             |
|--------------|:---------------:|:--------------:|:--------------:|
| SwiftFormat  | `swiftformat .` | ✅ auto-fix     | —              |
| SwiftLint    | build phase     | ✅ block        | ✅ `--strict`   |
| Unit tests   | ⌘U              | —              | ✅ required     |
| UI tests     | ⌘U              | —              | ✅ required     |
| Build .ipa   | archive         | —              | ✅ main only    |

**Golden rule: never let `main` go red.** If a gate fails in CI, fix forward or
revert — don't disable the gate.

### Run the gates manually

```bash
swiftformat --lint .        # check formatting (non-mutating)
swiftformat .               # auto-fix formatting
swiftlint lint --strict     # lint; warnings are errors
```

> The app target has a **SwiftLint run-script build phase**, so violations also
> surface as warnings in Xcode. `ENABLE_USER_SCRIPT_SANDBOXING` is set to `NO`
> at the project level so that phase can read source files — the standard
> configuration for a SwiftLint build phase.

---

## Testing

- **Unit tests** use the **Swift Testing** framework (`@Test`, `#expect`) and
  `@testable import SwiftBaseClassWAC`.
- **UI tests** use **XCUITest**, driving the UI through accessibility identifiers
  (e.g. `counter.value`, `counter.increment`).

```bash
xcodebuild test \
  -project "SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj" \
  -scheme "SwiftBaseClassWAC" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Dependencies

Use **Swift Package Manager** (built into Xcode): *File → Add Package Dependencies*.
Avoid CocoaPods/Carthage unless a package is SPM-incompatible.

---

## CI/CD (`.github/workflows/ci.yml`)

Order is intentional and **fails fast**:

```
lint (SwiftLint --strict)
  └─ test (unit + UI on simulator)
       └─ archive (.ipa, main branch only)
```

A broken lint stops the pipeline before the expensive build ever runs.

## Gate engine

The `gate` CLI (Swift package in `Tooling/`) runs the same quality pipeline,
scoped to what you're working on:

```bash
./gate screen Counter      # one screen: format + lint, then that screen's unit & UI tests
./gate screens Counter Posts
./gate branch              # only the screens changed vs. main
./gate all                 # whole repo (format → lint → build → test)
```

Config lives in `gate.yml`. See the design spec in
`docs/superpowers/specs/2026-06-04-wac-ios-standard-design.md`.

---

## Release pipeline checklist

### Phase 4 — Signing & provisioning (once per environment)
- [ ] Certificates: generate a CSR in Keychain Access → upload to Apple → install the `.cer`.
- [ ] App ID: register `com.wac.SwiftBaseClassWAC`; enable needed capabilities.
- [ ] Provisioning profile: link App ID + certificate; add device UDIDs for dev builds.
- [ ] Xcode: select Team, enable Automatic Signing for dev, add matching Capabilities.
- [ ] **Teams:** prefer `fastlane match` to sync signing assets via a private repo.

### Phase 5 — Git workflow & branch protection
- [ ] Short-lived feature branches off `main`; every change goes through a PR.
- [ ] Branch protection on `main`: require the `Lint` and `Build & Test` checks
      to pass and ≥1 review before merge.

### Phase 7 — Distribution
- [ ] `bundle exec fastlane beta` → uploads to TestFlight.
- [ ] Internal testing (team, near-instant) → External testing (Beta App Review).
- [ ] Collect crash reports & feedback; loop back to development.

### Phase 8 — Release
- [ ] `bundle exec fastlane release` (or App Store Connect) → submit for Apple Review.
- [ ] On approval → Production Release (manual / scheduled / phased).
- [ ] Tag the release: `git tag v1.0.0 && git push --tags`; bump the build number.

---

## fastlane lanes

| Lane      | What it does                                            |
|-----------|---------------------------------------------------------|
| `test`    | Runs the full test suite (mirrors CI).                  |
| `beta`    | match → bump build → build `.ipa` → upload to TestFlight |
| `release` | match → build `.ipa` → submit for App Store review.      |

Before using `beta`/`release`, complete the one-time account + credential setup
in [docs/RELEASE_SETUP.md](docs/RELEASE_SETUP.md). Credentials are read from the
environment (`fastlane/.env`, gitignored — see `fastlane/.env.example`).
