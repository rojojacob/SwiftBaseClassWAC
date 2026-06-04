//
//  Dependencies.swift
//  SwiftBaseClassWAC
//
//  Lightweight dependency container. The composition root (`.live`) builds the
//  real services once; views read it from the environment and pass what each
//  view model needs through the view model's initializer (constructor
//  injection) — which keeps view models trivially mockable in tests.
//

import Foundation
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
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(uiTestStubArgument) {
                return Dependencies(apiClient: UITestStubAPIClient(), keychain: KeychainStore(), logger: .app)
            }
        #endif
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

#if DEBUG
    /// Launch argument that swaps the live API client for an offline, deterministic
    /// stub so UI tests exercising networked screens never touch the network.
    /// Keep this string in sync with the literal used in `HomeFlowUITests`.
    private let uiTestStubArgument = "-uiTestStubAPI"

    /// Offline API client used only under `-uiTestStubAPI` in DEBUG builds. Returns
    /// canned data so UI regressions are hermetic and never flake on the network.
    private struct UITestStubAPIClient: APIClient {
        func request<Response: Decodable & Sendable>(
            _ endpoint: Endpoint,
            as _: Response.Type
        ) async throws -> Response {
            switch endpoint.path {
            case "posts":
                let posts = [
                    Post(id: 1, title: "First post", body: "Body of the first stubbed post."),
                    Post(id: 2, title: "Second post", body: "Body of the second stubbed post."),
                    Post(id: 3, title: "Third post", body: "Body of the third stubbed post.")
                ]
                guard let response = posts as? Response else {
                    throw URLError(.cannotDecodeContentData)
                }
                return response
            default:
                throw URLError(.unsupportedURL)
            }
        }

        func send(_: Endpoint) async throws {}
    }
#endif
