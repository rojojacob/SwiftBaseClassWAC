/// Minimal single-`*` glob matcher (sufficient for the test_glob convention).
/// Uses stdlib `split` (no Foundation import needed).
public enum Glob {
    public static func matches(_ pattern: String, name: String) -> Bool {
        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return name == pattern }
        let prefix = parts.first ?? ""
        let suffix = parts.last ?? ""
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return false }
        return name.count >= prefix.count + suffix.count
    }
}
