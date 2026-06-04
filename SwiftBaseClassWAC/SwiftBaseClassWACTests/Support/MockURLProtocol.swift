//
//  MockURLProtocol.swift
//  SwiftBaseClassWACTests
//
//  A URLProtocol that intercepts requests so the networking layer can be
//  tested deterministically without hitting the network. Install it on an
//  ephemeral URLSession and set `requestHandler` per test.
//

import Foundation

// Test infrastructure: force-unwrapping known-good values is fine here, and the
// `class func` overrides are required by URLProtocol (can't be `static`).
// swiftlint:disable force_unwrapping static_over_final_class

final class MockURLProtocol: URLProtocol {
    /// Returns the (response, body) to serve, or throws to simulate a transport error.
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    /// A URLSession wired to use this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Convenience: serve `data` with the given status code for any request.
    static func stub(statusCode: Int, data: Data) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// swiftlint:enable force_unwrapping static_over_final_class
