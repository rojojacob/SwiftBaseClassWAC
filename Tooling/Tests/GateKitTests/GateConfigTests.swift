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
    #expect(config.project == "App/App.xcodeproj")
    #expect(config.targets.app == "App")
    #expect(config.targets.ui == "AppUITests")
    #expect(config.simulator == "iPhone 16")
    #expect(config.conventions.unitDir == "App/AppTests")
    #expect(config.conventions.uiDir == "App/AppUITests")
}

@Test func parseFailsOnGarbage() {
    let error = #expect(throws: GateConfigError.self) {
        _ = try GateConfig.parse("not: [valid")
    }
    guard case .parseFailed? = error else {
        Issue.record("expected GateConfigError.parseFailed, got \(String(describing: error))")
        return
    }
}

@Test func parsesOptionalHealthThreshold() throws {
    let yaml = """
    project: App/App.xcodeproj
    scheme: App
    targets: { app: App, unit: AppTests, ui: AppUITests }
    simulator: "iPhone 16 Pro"
    base_branch: main
    conventions:
      features_dir: App/App/Features
      unit_dir: App/AppTests
      ui_dir: App/AppUITests
      test_glob: "{Name}*Tests.swift"
      shared_dirs: [Core]
    stages: [format, lint, test]
    thresholds: { health_min: 80 }
    """
    let config = try GateConfig.parse(yaml)
    #expect(config.thresholds?.healthMin == 80)
}

@Test func thresholdsAreOptional() {
    #expect(makeTestConfig().thresholds == nil)
}
