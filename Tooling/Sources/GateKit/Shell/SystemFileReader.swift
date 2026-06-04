import Foundation

/// Real `FileReading` over the local filesystem.
public struct SystemFileReader: FileReading {
    public init() {}

    public func contents(of path: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }

    public func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
