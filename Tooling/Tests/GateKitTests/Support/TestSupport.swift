import Foundation
@testable import GateKit

/// Shared test fixtures. `makeContext(runner:)` is appended in Task 8 (after
/// GateContext exists). Avoid `try!` here — the pre-commit `swiftlint --strict`
/// hook flags `force_try`, so use do/catch + fatalError instead.
func makeTestConfig() -> GateConfig {
    do {
        return try GateConfig.parse("""
        project: App/App.xcodeproj
        scheme: App
        targets: { app: App, unit: AppTests, ui: AppUITests }
        simulator: "iPhone 16"
        base_branch: main
        conventions:
          features_dir: App/App/Features
          unit_dir: App/AppTests
          ui_dir: App/AppUITests
          test_glob: "{Name}*Tests.swift"
          shared_dirs: [Core, DesignSystem]
        stages: [format, lint, build, test]
        """)
    } catch {
        fatalError("invalid test YAML: \(error)")
    }
}
