//
//  Endpoint.swift
//  SwiftBaseClassWAC
//
//  Declarative description of a single API request. Build one per route and
//  hand it to `APIClient` — the client composes it against the configured base
//  URL, applies interceptors, sends it, and decodes the response.
//

import Foundation

struct Endpoint {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    /// Convenience for a JSON body: encodes `value` and sets the content-type.
    static func json(
        _ path: String,
        method: HTTPMethod = .post,
        body: some Encodable,
        encoder: JSONEncoder = JSONEncoder(),
        queryItems: [URLQueryItem] = []
    ) throws -> Endpoint {
        var endpoint = Endpoint(path: path, method: method, queryItems: queryItems)
        endpoint.body = try encoder.encode(body)
        endpoint.headers["Content-Type"] = "application/json"
        return endpoint
    }

    /// Builds a `URLRequest` by resolving this endpoint against `baseURL`.
    func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
