//
//  RequestInterceptor.swift
//  SwiftBaseClassWAC
//
//  Mutates outgoing requests before they're sent — the seam for injecting
//  auth tokens, common headers, etc. Interceptors run in order.
//

import Foundation

protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

/// Injects a bearer token (fetched lazily, so it always uses the latest value)
/// into the `Authorization` header.
struct BearerTokenInterceptor: RequestInterceptor {
    let token: @Sendable () async -> String?

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        guard let token = await token() else { return request }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

/// Adds a fixed set of headers to every request (e.g. Accept, app version).
struct DefaultHeadersInterceptor: RequestInterceptor {
    let headers: [String: String]

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        for (field, value) in headers where request.value(forHTTPHeaderField: field) == nil {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
