import Foundation

/// Matches a file `name` against a glob `pattern`.
/// No `*` means an exact match; each `*` matches any run of characters.
public enum Glob {
    public static func matches(_ pattern: String, name: String) -> Bool {
        let parts = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return name == pattern }

        let prefix = parts[0]
        let suffix = parts[parts.count - 1]
        guard name.hasPrefix(prefix), name.count >= prefix.count + suffix.count else { return false }

        var remainder = Substring(name).dropFirst(prefix.count)
        guard remainder.hasSuffix(suffix) else { return false }
        remainder = remainder.dropLast(suffix.count)

        // Interior segments (between stars) must appear in order.
        for segment in parts[1 ..< (parts.count - 1)] where !segment.isEmpty {
            guard let found = remainder.range(of: segment) else { return false }
            remainder = remainder[found.upperBound...]
        }
        return true
    }
}
