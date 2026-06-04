import Foundation
import Yams

public struct GateTargets: Codable, Equatable, Sendable {
    public let app: String
    public let unit: String
    public let ui: String
}

public struct GateConventions: Codable, Equatable, Sendable {
    public let featuresDir: String
    public let unitDir: String
    public let uiDir: String
    public let testGlob: String
    public let sharedDirs: [String]

    enum CodingKeys: String, CodingKey {
        case featuresDir = "features_dir"
        case unitDir = "unit_dir"
        case uiDir = "ui_dir"
        case testGlob = "test_glob"
        case sharedDirs = "shared_dirs"
    }
}

public struct GateThresholds: Codable, Equatable, Sendable {
    public let healthMin: Int

    enum CodingKeys: String, CodingKey {
        case healthMin = "health_min"
    }
}

public struct GateConfig: Codable, Equatable, Sendable {
    public let project: String
    public let scheme: String
    public let targets: GateTargets
    public let simulator: String
    public let baseBranch: String
    public let conventions: GateConventions
    public let stages: [String]
    public let thresholds: GateThresholds?

    enum CodingKeys: String, CodingKey {
        case project, scheme, targets, simulator, conventions, stages, thresholds
        case baseBranch = "base_branch"
    }
}

public enum GateConfigError: Error {
    case fileNotFound(String)
    case parseFailed(String)
}

public extension GateConfig {
    static func parse(_ yaml: String) throws -> GateConfig {
        do {
            return try YAMLDecoder().decode(GateConfig.self, from: yaml)
        } catch {
            throw GateConfigError.parseFailed(String(describing: error))
        }
    }

    static func load(from url: URL) throws -> GateConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GateConfigError.fileNotFound(url.path)
        }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw GateConfigError.parseFailed("could not read \(url.path): \(error)")
        }
        return try parse(text)
    }
}
