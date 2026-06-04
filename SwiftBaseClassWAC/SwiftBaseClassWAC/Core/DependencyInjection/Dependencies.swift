//
//  Dependencies.swift
//  SwiftBaseClassWAC
//
//  Lightweight dependency container. The composition root (`.live`) builds the
//  real services once; views read it from the environment and pass what each
//  view model needs through the view model's initializer (constructor
//  injection) — which keeps view models trivially mockable in tests.
//

import SwiftUI

struct Dependencies {
    var apiClient: any APIClient
    var keychain: any SecureStore
    var logger: AppLogger

    /// Well-known keychain keys.
    enum Key {
        static let accessToken = "auth.accessToken"
    }

    /// The production composition root.
    static let live: Dependencies = {
        let keychain = KeychainStore()
        let interceptors: [any RequestInterceptor] = [
            DefaultHeadersInterceptor(headers: ["Accept": "application/json"]),
            BearerTokenInterceptor { keychain.string(for: Key.accessToken) }
        ]
        let apiClient = DefaultAPIClient(
            baseURL: AppConfiguration.current.apiBaseURL,
            interceptors: interceptors
        )
        return Dependencies(apiClient: apiClient, keychain: keychain, logger: .app)
    }()
}

// MARK: - SwiftUI environment injection

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue: Dependencies = .live
}

extension EnvironmentValues {
    var dependencies: Dependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}

extension View {
    /// Injects a dependency container (use in previews/tests to supply mocks).
    func dependencies(_ dependencies: Dependencies) -> some View {
        environment(\.dependencies, dependencies)
    }
}
