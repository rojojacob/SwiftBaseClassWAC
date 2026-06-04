import Foundation

/// Reads file contents and checks existence. The hashing/stamp layers depend on
/// this protocol so they can be unit-tested without touching the real disk.
public protocol FileReading {
    func contents(of path: String) throws -> Data
    func exists(_ path: String) -> Bool
}
