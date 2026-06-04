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
  SwiftBaseClassWAC/            # app target (synchronized folder group)
    App/                           # entry point + composition root (RootView)
    Features/                      # one folder per feature
      Counter/                     #   sample MVVM vertical: View + ViewModel + Model
    Core/                          # shared services
      Networking/                  #   APIClient abstraction
    DesignSystem/                  # tokens (spacing/color/typography) + components
    Resources/                     # Assets.xcassets
  SwiftBaseClassWACTests/       # unit tests (Swift Testing)
  SwiftBaseClassWACUITests/     # UI tests (XCUITest)
.github/workflows/ci.yml           # CI: lint -> test -> archive (fail fast)
fastlane/                          # signing + TestFlight + App Store lanes
.swiftlint.yml  .swiftformat  lefthook.yml
```

> **Note on test folders:** Xcode synchronized groups mean source files are
> auto-discovered — just drop a `.swift` file in any folder under the app target
> and it compiles. Test *targets* must live in their own sibling folders
> (`…Tests` / `…UITests`), which is why they sit outside the app folder rather
> than in a nested `Tests/` directory.

---

## First-time setup

```bash
# 1. Quality tools
brew install swiftlint swiftformat lefthook

# 2. Install git hooks (pre-commit format+lint, pre-push lint)
lefthook install

# 3. (Optional) fastlane for signing/distribution
bundle install
```

Open `SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj`, then **⌘R** to run and
**⌘U** to test.

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
