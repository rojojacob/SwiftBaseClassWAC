import Foundation

/// Stores the stamp at `<repoRoot>/.gate/last-green.json`. A missing or
/// unreadable file is treated as an empty stamp (first run is never wedged).
public struct SystemStampStore: StampStoring {
    private let url: URL
    private let directory: URL

    public init(repoRoot: URL) {
        directory = repoRoot.appendingPathComponent(".gate", isDirectory: true)
        url = directory.appendingPathComponent("last-green.json")
    }

    public func load() -> Stamp {
        guard let data = try? Data(contentsOf: url),
              let stamp = try? JSONDecoder().decode(Stamp.self, from: data)
        else {
            return Stamp(hashes: [:])
        }
        return stamp
    }

    public func save(_ stamp: Stamp) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stamp) else { return }
        try? data.write(to: url)
    }
}
