/// Finds source files under a directory whose basename matches a single-`*` glob.
public protocol FileFinder {
    func files(in directory: String, matching pattern: String) -> [String]
}
