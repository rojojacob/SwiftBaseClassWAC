//
//  MockAPIClient.swift
//  SwiftBaseClassWACTests
//
//  In-memory APIClient for view-model tests. Stub `result` with JSON to decode
//  or an error to throw; inspect `requestedPaths` to assert what was called.
//

import Foundation
@testable import SwiftBaseClassWAC

final class MockAPIClient: APIClient, @unchecked Sendable {
    enum Stub {
        case json(Data)
        case failure(any Error)
    }

    var result: Stub
    private(set) var requestedPaths: [String] = []

    init(result: Stub = .json(Data("[]".utf8))) {
        self.result = result
    }

    /// Convenience: stub a successful response by encoding `value`.
    static func returning(_ value: some Encodable) -> MockAPIClient {
        MockAPIClient(result: .json((try? JSONEncoder().encode(value)) ?? Data()))
    }

    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint, as _: Response.Type) async throws -> Response {
        requestedPaths.append(endpoint.path)
        switch result {
        case let .json(data): return try JSONDecoder.apiDefault.decode(Response.self, from: data)
        case let .failure(error): throw error
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        requestedPaths.append(endpoint.path)
        if case let .failure(error) = result { throw error }
    }
}
