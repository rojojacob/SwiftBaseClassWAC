//
//  EndpointTests.swift
//  SwiftBaseClassWACTests
//

import Foundation
import Testing
@testable import SwiftBaseClassWAC

struct EndpointTests {
    private let baseURL = URL(string: "https://api.test") ?? URL(fileURLWithPath: "/")

    @Test func buildsURLWithPathAndQuery() throws {
        let endpoint = Endpoint(
            path: "search",
            queryItems: [URLQueryItem(name: "q", value: "swift")]
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)
        #expect(request.url?.absoluteString == "https://api.test/search?q=swift")
        #expect(request.httpMethod == "GET")
    }

    @Test func appliesMethodHeadersAndBody() throws {
        var endpoint = Endpoint(path: "items", method: .post)
        endpoint.headers["X-Test"] = "1"
        endpoint.body = Data("payload".utf8)

        let request = try endpoint.urlRequest(baseURL: baseURL)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Test") == "1")
        #expect(request.httpBody == Data("payload".utf8))
    }

    @Test func jsonHelperEncodesBodyAndSetsContentType() throws {
        let endpoint = try Endpoint.json("items", body: ["name": "a"])
        let request = try endpoint.urlRequest(baseURL: baseURL)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody != nil)
    }
}
