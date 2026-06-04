@testable import GateKit

final class FakeFileFinder: FileFinder {
    /// Maps a directory path to the files it should "contain".
    var filesByDirectory: [String: [String]] = [:]
    var subdirsByDirectory: [String: [String]] = [:]

    func files(in directory: String, matching pattern: String) -> [String] {
        (filesByDirectory[directory] ?? []).filter { path in
            let name = path.split(separator: "/").last.map(String.init) ?? path
            return name.hasSuffix(".swift") && Glob.matches(pattern, name: name)
        }
    }

    func subdirectories(of directory: String) -> [String] {
        (subdirsByDirectory[directory] ?? []).sorted()
    }
}
