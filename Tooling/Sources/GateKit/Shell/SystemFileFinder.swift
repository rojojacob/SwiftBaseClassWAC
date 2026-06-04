import Foundation

public struct SystemFileFinder: FileFinder {
    public init() {}

    public func files(in directory: String, matching pattern: String) -> [String] {
        let base = URL(fileURLWithPath: directory)
        guard let enumerator = FileManager.default.enumerator(
            at: base, includingPropertiesForKeys: nil
        ) else { return [] }

        var matches: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if Glob.matches(pattern, name: url.lastPathComponent) {
                matches.append(url.path)
            }
        }
        return matches.sorted()
    }
}
