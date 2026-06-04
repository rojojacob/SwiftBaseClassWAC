import CryptoKit
import Foundation

/// Computes a content hash for a screen from its source plus its unit and UI test
/// files: every `.swift` under the screen's code path together with its test files.
/// Any edit to code or tests changes the hash, which is what the verification stamp
/// compares against.
public struct ScreenHasher {
    private let finder: FileFinder
    private let reader: FileReading
    private let repoRoot: URL

    public init(finder: FileFinder, reader: FileReading, repoRoot: URL) {
        self.finder = finder
        self.reader = reader
        self.repoRoot = repoRoot
    }

    public func hash(_ screen: Screen) throws -> String {
        let codeDir = repoRoot.appendingPathComponent(screen.codePath).path
        let sourceFiles = finder.files(in: codeDir, matching: "*.swift")
        // Sort so the hash is independent of filesystem enumeration order.
        let paths = (sourceFiles + screen.unitTestFiles + screen.uiTestFiles).sorted()
        let rootPrefix = repoRoot.path.hasSuffix("/") ? repoRoot.path : repoRoot.path + "/"

        var hasher = SHA256()
        for path in paths {
            // Mix the REPO-RELATIVE path in too, so moving identical content between
            // files changes the hash while the hash stays independent of checkout location.
            let relative = path.hasPrefix(rootPrefix) ? String(path.dropFirst(rootPrefix.count)) : path
            hasher.update(data: Data(relative.utf8))
            try hasher.update(data: reader.contents(of: path))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
