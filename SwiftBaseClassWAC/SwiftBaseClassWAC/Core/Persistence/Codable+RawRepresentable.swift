//
//  Codable+RawRepresentable.swift
//  SwiftBaseClassWAC
//
//  Lets `Codable` collections be stored directly in `@AppStorage` /
//  `@SceneStorage` by bridging them through a JSON string `rawValue`.
//
//  Example:
//      @AppStorage("recentSearches") private var searches: [String] = []
//

import Foundation

extension Array: @retroactive RawRepresentable where Element: Codable {
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = decoded
    }
}

extension Dictionary: @retroactive RawRepresentable where Key: Codable, Value: Codable {
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        self = decoded
    }
}
