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
            if let stub = UITestStubAPIClient.fromLaunchArguments() {
                return Dependencies(apiClient: stub, keychain: KeychainStore(), logger: .app)
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
    /// Launch arguments that swap the live API client for an offline, deterministic
    /// stub so UI tests exercising networked screens never touch the network. Keep
    /// these strings in sync with the literals used in the UI tests.
    private enum UITestStubArgument {
        static let populated = "-uiTestStubAPI"
        static let empty = "-uiTestPostsEmpty"
        static let error = "-uiTestPostsError"
    }

    /// Offline API client used only under a UI-test launch argument in DEBUG builds.
    /// Returns canned posts, an empty list, or an error so UI regressions are hermetic.
    private struct UITestStubAPIClient: APIClient {
        enum PostsMode { case populated, empty, error }

        let postsMode: PostsMode

        /// Builds a stub from the process launch arguments, or nil if none apply.
        static func fromLaunchArguments() -> UITestStubAPIClient? {
            let args = ProcessInfo.processInfo.arguments
            if args.contains(UITestStubArgument.error) { return UITestStubAPIClient(postsMode: .error) }
            if args.contains(UITestStubArgument.empty) { return UITestStubAPIClient(postsMode: .empty) }
            if args.contains(UITestStubArgument.populated) { return UITestStubAPIClient(postsMode: .populated) }
            return nil
        }

        func request<Response: Decodable & Sendable>(
            _ endpoint: Endpoint,
            as _: Response.Type
        ) async throws -> Response {
            switch endpoint.path {
            case "posts":
                return try postsResponse()
            default:
                throw URLError(.unsupportedURL)
            }
        }

        func send(_: Endpoint) async throws {}

        private func postsResponse<Response: Decodable & Sendable>() throws -> Response {
            switch postsMode {
            case .error:
                throw URLError(.notConnectedToInternet)
            case .empty:
                guard let response = [Post]() as? Response else {
                    throw URLError(.cannotDecodeContentData)
                }
                return response
            case .populated:
                let posts = [
                    Post(id: 1, title: "First post", body: "Body of the first stubbed post."),
                    Post(id: 2, title: "Second post", body: "Body of the second stubbed post."),
                    Post(id: 3, title: "Third post", body: "Body of the third stubbed post.")
                ]
                guard let response = posts as? Response else {
                    throw URLError(.cannotDecodeContentData)
                }
                return response
            }
        }
    }
#endif
