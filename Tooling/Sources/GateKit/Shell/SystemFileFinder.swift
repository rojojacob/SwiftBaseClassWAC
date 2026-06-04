import Foundation

public struct SystemFileFinder: FileFinder {
    public init() {}

    public func files(in directory: String, matching pattern: String) -> [String] {
        let base = URL(fileURLWithPath: directory)
        // Recurse the subtree, skipping hidden dirs (.git/.build); silently ignore
        // unreadable entries. Returns the `.swift` files whose basename matches the glob.
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var matches: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            if Glob.matches(pattern, name: url.lastPathComponent) {
                matches.append(url.path)
            }
        }
        return matches.sorted()
    }

    public func subdirectories(of directory: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return entries.filter { name in
            var isDir: ObjCBool = false
            let path = (directory as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }.sorted()
    }
}
