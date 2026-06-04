import Foundation
@testable import GateKit

final class FakeFileReader: FileReading {
    var filesByPath: [String: Data] = [:]

    func contents(of path: String) throws -> Data {
        guard let data = filesByPath[path] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }

    func exists(_ path: String) -> Bool {
        filesByPath[path] != nil
    }
}
