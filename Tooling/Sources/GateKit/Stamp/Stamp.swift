import Foundation

/// The per-screen verification stamp: screen name → content hash of its last
/// green run. Persisted as `.gate/last-green.json`.
public struct Stamp: Codable, Equatable, Sendable {
    public private(set) var hashes: [String: String]

    public init(hashes: [String: String]) {
        self.hashes = hashes
    }

    /// Overwrites the hashes for the given screens, leaving the rest untouched.
    public mutating func merge(_ updates: [String: String]) {
        hashes.merge(updates) { _, new in new }
    }
}

/// Reads/writes the stamp. Mockable so stamp logic is unit-tested off-disk.
public protocol StampStoring {
    func load() -> Stamp
    func save(_ stamp: Stamp)
}
