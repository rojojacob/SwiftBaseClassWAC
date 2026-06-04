//
//  APIClientTests.swift
//  SwiftBaseClassWACTests
//
//  Deterministic networking tests via MockURLProtocol — no real network.
//

import Foundation
import Testing
@testable import SwiftBaseClassWAC

// Force-unwrapping known-good values is fine in test code.
// swiftlint:disable force_unwrapping

@Suite(.serialized) // tests share MockURLProtocol's static handler
struct APIClientTests {
    private let baseURL = URL(string: "https://api.test")!

    private func makeClient(interceptors: [any RequestInterceptor] = []) -> DefaultAPIClient {
        DefaultAPIClient(
            baseURL: baseURL,
            httpClient: MockURLProtocol.makeSession(),
            interceptors: interceptors
        )
    }

    @Test func decodesSuccessfulResponse() async throws {
        let json = Data(#"{"id": 7, "title": "Hello", "body": "World"}"#.utf8)
        MockURLProtocol.stub(statusCode: 200, data: json)

        let post = try await makeClient().request(Endpoint(path: "posts/7"), as: Post.self)

        #expect(post.id == 7)
        #expect(post.title == "Hello")
    }

    @Test func throwsHTTPErrorWithBodyOnNon2xx() async throws {
        let body = Data(#"{"message": "nope"}"#.utf8)
        MockURLProtocol.stub(statusCode: 404, data: body)

        await #expect(throws: APIError.self) {
            try await makeClient().request(Endpoint(path: "posts/0"), as: Post.self)
        }

        do {
            _ = try await makeClient().request(Endpoint(path: "posts/0"), as: Post.self)
        } catch let error as APIError {
            guard case let .http(status, data) = error else {
                Issue.record("Expected .http, got \(error)")
                return
            }
            #expect(status == 404)
            #expect(data == body) // server error body is preserved
        }
    }

    @Test func throwsDecodingErrorOnMalformedBody() async {
        MockURLProtocol.stub(statusCode: 200, data: Data("not json".utf8))

        await #expect(throws: APIError.self) {
            try await makeClient().request(Endpoint(path: "posts/1"), as: Post.self)
        }
    }

    @Test func interceptorMutatesOutgoingRequest() async throws {
        let header = LockedValue<String?>(nil)
        MockURLProtocol.requestHandler = { request in
            header.value = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let interceptor = BearerTokenInterceptor { "abc123" }
        _ = try await makeClient(interceptors: [interceptor]).request(Endpoint(path: "posts"), as: [Post].self)

        #expect(header.value == "Bearer abc123")
    }
}

/// Tiny thread-safe box so the URLProtocol handler can hand a value back.
private final class LockedValue<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) {
        stored = value
    }

    var value: T {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

// swiftlint:enable force_unwrapping
