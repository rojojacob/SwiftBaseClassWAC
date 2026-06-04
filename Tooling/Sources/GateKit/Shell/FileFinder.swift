/// Finds `.swift` source files under a directory whose basename matches a single-`*` glob.
public protocol FileFinder {
    /// `.swift` source files under `directory` whose name matches the `*` glob.
    func files(in directory: String, matching pattern: String) -> [String]
    /// Immediate subdirectory names of `directory` (one level, no recursion),
    /// excluding hidden dirs, returned in sorted order.
    func subdirectories(of directory: String) -> [String]
}
