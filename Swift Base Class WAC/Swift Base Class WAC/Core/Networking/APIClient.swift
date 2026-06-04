//
//  APIClient.swift
//  Swift Base Class WAC
//
//  Minimal async networking abstraction. The protocol lets view models
//  depend on an interface (easy to mock in tests) rather than URLSession.
//

import Foundation

protocol APIClient: Sendable {
    func get<Response: Decodable>(_ endpoint: URL, as type: Response.Type) async throws -> Response
}

enum APIError: Error, Equatable {
    case invalidResponse(statusCode: Int)
    case decoding
}

struct URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func get<Response: Decodable>(_ endpoint: URL, as _: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(from: endpoint)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: -1)
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw APIError.invalidResponse(statusCode: http.statusCode)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
