//
//  APIClient.swift
//  SwiftBaseClassWAC
//
//  Endpoint-driven async networking client. View models depend on the
//  `APIClient` protocol (easy to mock); `DefaultAPIClient` is the live impl
//  built on the `HTTPClient` seam + request interceptors.
//

import Foundation

protocol APIClient: Sendable {
    /// Sends `endpoint` and decodes the 2xx JSON body into `Response`.
    func request<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: Response.Type
    ) async throws -> Response

    /// Sends `endpoint` and ignores the body (for 204/empty responses).
    func send(_ endpoint: Endpoint) async throws
}

extension APIClient {
    /// Overload that infers `Response` from the call site.
    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        try await request(endpoint, as: Response.self)
    }
}

struct DefaultAPIClient: APIClient {
    private let baseURL: URL
    private let httpClient: any HTTPClient
    private let decoder: JSONDecoder
    private let interceptors: [any RequestInterceptor]

    init(
        baseURL: URL,
        httpClient: any HTTPClient = URLSession.shared,
        decoder: JSONDecoder = .apiDefault,
        interceptors: [any RequestInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.decoder = decoder
        self.interceptors = interceptors
    }

    func request<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as _: Response.Type
    ) async throws -> Response {
        let data = try await perform(endpoint)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    /// Builds the request, applies interceptors, sends it, and validates the
    /// status code. Returns the raw 2xx body.
    @discardableResult
    private func perform(_ endpoint: Endpoint) async throws -> Data {
        var request = try endpoint.urlRequest(baseURL: baseURL)
        for interceptor in interceptors {
            request = try await interceptor.adapt(request)
        }
        let (data, response) = try await httpClient.send(request)
        guard response.statusCode.isSuccessStatus else {
            throw APIError.http(status: response.statusCode, data: data)
        }
        return data
    }
}

extension JSONDecoder {
    /// Decoder used across the API: ISO-8601 dates, snake_case keys.
    static var apiDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
