# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Networking:** `Endpoint` abstraction, `HTTPClient` seam over URLSession,
  `RequestInterceptor` (bearer/header), richer `APIError` (carries server body)
  and `HTTPStatus`; `DefaultAPIClient` (endpoint → interceptors → decode).
- **Dependency injection:** `Dependencies` container + SwiftUI environment.
- **Persistence:** `KeychainStore` (secure token storage); `Codable`
  `RawRepresentable` bridge for `@AppStorage` collections.
- **Configuration:** `AppConfiguration` / `AppEnvironment` (dev/staging/prod).
- **Logging:** OSLog-based `AppLogger`.
- **SwiftUI toolkit:** `.onFirstAppear`, `AsyncButton`, `ValidatedTextField` +
  `ValidationRule`, `.errorAlert`, and a `Router` for `NavigationStack`.
- **Sample feature:** networked `Posts` list + detail.
- **Testing:** `MockURLProtocol`, `MockAPIClient`, networking/endpoint/view-model/
  validation unit tests (Swift Testing), and XCUITest page-object helpers.
- **Tooling:** `Brewfile`, `scripts/` (`preflight.sh`, feature scaffolder,
  shared helpers), Conventional-Commits `commit-msg` hook, GitHub issue/PR
  templates, `.editorconfig`, `CONTRIBUTING.md`.

## [1.0.0]

### Added
- Initial SwiftUI base project: MVVM (`@Observable`), SwiftLint/SwiftFormat,
  Lefthook, Swift Testing + XCUITest, GitHub Actions CI, and fastlane
  (match + TestFlight) release pipeline.
