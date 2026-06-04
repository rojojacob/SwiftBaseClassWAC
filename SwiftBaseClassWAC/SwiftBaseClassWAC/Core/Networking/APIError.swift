//
//  APIError.swift
//  SwiftBaseClassWAC
//
//  Errors surfaced by the networking layer. HTTP failures carry the raw
//  response body so callers can decode a typed server-error payload.
//

import Foundation

enum APIError: Error {
    /// The endpoint could not be turned into a valid URL.
    case invalidURL
    /// The transport failed (no connection, timeout, cancelled, …).
    case transport(any Error)
    /// The response was not an HTTP response.
    case invalidResponse
    /// A non-2xx status code. `data` is the raw response body, if any.
    case http(status: Int, data: Data)
    /// The 2xx body could not be decoded into the expected type.
    case decoding(any Error)

    /// `true` for 401 Unauthorized — useful for triggering a re-auth flow.
    var isUnauthorized: Bool {
        if case let .http(status, _) = self { return status == 401 }
        return false
    }

    /// Attempts to decode the HTTP error body into a typed server payload.
    func serverError<T: Decodable>(as _: T.Type, decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard case let .http(_, data) = self, !data.isEmpty else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The request URL was invalid."
        case let .transport(error):
            error.localizedDescription
        case .invalidResponse:
            "The server returned an unexpected response."
        case let .http(status, _):
            "The request failed with status code \(status)."
        case .decoding:
            "The server response could not be read."
        }
    }
}
