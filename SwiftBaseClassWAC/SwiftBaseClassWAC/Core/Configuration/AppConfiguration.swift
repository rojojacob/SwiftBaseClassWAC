//
//  AppConfiguration.swift
//  SwiftBaseClassWAC
//
//  Typed, runtime-readable build configuration. Values are supplied per
//  environment via xcconfig → Info.plist (see Config/*.xcconfig) so they're
//  testable and don't require `#if` branching scattered through the code.
//

import Foundation

enum AppEnvironment: String {
    case development
    case staging
    case production

    /// The environment baked into this build (from Info.plist `APP_ENVIRONMENT`).
    static let current: AppEnvironment = {
        let raw = Bundle.main.infoValue(for: "APP_ENVIRONMENT") ?? ""
        return AppEnvironment(rawValue: raw.lowercased()) ?? .development
    }()

    var isProduction: Bool {
        self == .production
    }
}

struct AppConfiguration {
    let environment: AppEnvironment
    let apiBaseURL: URL

    /// The active configuration for this build.
    static let current: AppConfiguration = {
        let environment = AppEnvironment.current
        // Fallback chain (no force-unwrap): xcconfig value → literal default →
        // a guaranteed non-optional URL that is never actually reached.
        let baseURL = Bundle.main.infoValue(for: "API_BASE_URL")
            .flatMap { URL(string: $0.addingHTTPSchemeIfMissing) }
            ?? URL(string: "https://api.example.com")
            ?? URL(fileURLWithPath: "/")
        return AppConfiguration(environment: environment, apiBaseURL: baseURL)
    }()
}

private extension Bundle {
    /// Reads a non-empty string from Info.plist, trimming whitespace.
    func infoValue(for key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    /// xcconfig can't store `//`, so base URLs are stored without a scheme
    /// (e.g. `api.example.com`); add `https://` if no scheme is present.
    var addingHTTPSchemeIfMissing: String {
        contains("://") ? self : "https://\(self)"
    }
}
