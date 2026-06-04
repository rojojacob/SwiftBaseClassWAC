//
//  HTTPClient.swift
//  SwiftBaseClassWAC
//
//  Thin seam over URLSession so the networking layer can be unit-tested
//  without hitting the network (inject a stub conforming to HTTPClient).
//

import Foundation

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await self.data(for: request, delegate: nil)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }
}
