# Contributing

## Setup

```bash
brew bundle        # installs swiftlint, swiftformat, lefthook, xcbeautify
lefthook install   # installs git hooks (pre-commit, commit-msg, pre-push)
bundle install     # fastlane (for signing/release; see docs/RELEASE_SETUP.md)
```

## Day-to-day

- **Run / test in Xcode:** open `SwiftBaseClassWAC/SwiftBaseClassWAC.xcodeproj`, ⌘R / ⌘U.
- **Scaffold a feature:** `./scripts/scaffold-feature.sh <FeatureName>` creates
  Model + ViewModel + View + a unit test under `Features/<FeatureName>/`.
- **Before pushing:** `./scripts/preflight.sh` runs the same gate as CI
  (SwiftFormat check → SwiftLint strict → build → test).

## Conventions

- **Architecture:** MVVM with `@Observable` view models; one folder per feature
  under `Features/`. Shared services live in `Core/`, reusable UI in `DesignSystem/`.
- **Dependency injection:** view models take their dependencies via `init` with a
  live default (`Dependencies.live.*`); tests pass mocks (`MockAPIClient`).
- **Branches:** short-lived branches off `main`; every change via PR.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `chore:`, …) — enforced by the `commit-msg` hook.
- **Quality gates:** SwiftFormat + SwiftLint (strict) must pass; never let `main` go red.

## Releasing

See [docs/RELEASE_SETUP.md](docs/RELEASE_SETUP.md). TestFlight builds go out via the
**TestFlight** GitHub Actions workflow or `bundle exec fastlane beta`.
