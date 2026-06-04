import Foundation
import Testing
@testable import GateKit

private let sampleYAML = """
project: App/App.xcodeproj
scheme: App
targets:
  app: App
  unit: AppTests
  ui: AppUITests
simulator: "iPhone 16"
base_branch: main
conventions:
  features_dir: App/App/Features
  unit_dir: App/AppTests
  ui_dir: App/AppUITests
  test_glob: "{Name}*Tests.swift"
  shared_dirs: [Core, DesignSystem]
stages: [format, lint, build, test]
"""

@Test func parsesAllFields() throws {
    let config = try GateConfig.parse(sampleYAML)
    #expect(config.scheme == "App")
    #expect(config.targets.unit == "AppTests")
    #expect(config.baseBranch == "main")
    #expect(config.conventions.featuresDir == "App/App/Features")
    #expect(config.conventions.testGlob == "{Name}*Tests.swift")
    #expect(config.conventions.sharedDirs == ["Core", "DesignSystem"])
    #expect(config.stages == ["format", "lint", "build", "test"])
}

@Test func parseFailsOnGarbage() {
    #expect(throws: GateConfigError.self) {
        _ = try GateConfig.parse("not: [valid")
    }
}
