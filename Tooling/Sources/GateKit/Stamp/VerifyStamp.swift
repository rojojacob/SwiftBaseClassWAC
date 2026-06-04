import Foundation

/// Compares each screen's current content hash to its stamped hash. Any
/// mismatch (or never-stamped screen) is "stale" → the build phase fails.
public struct VerifyStamp {
    let screens: () -> [Screen]
    let hasher: ScreenHasher
    private let store: StampStoring

    public init(screens: @escaping () -> [Screen], hasher: ScreenHasher, store: StampStoring) {
        self.screens = screens
        self.hasher = hasher
        self.store = store
    }

    public struct Result: Equatable {
        public let passed: Bool
        public let staleScreens: [String]
        public let skipped: Bool
    }

    public func run(skip: Bool) throws -> Result {
        if skip {
            return Result(passed: true, staleScreens: [], skipped: true)
        }
        let stamp = store.load()
        var stale: [String] = []
        for screen in screens() where try hasher.hash(screen) != stamp.hashes[screen.name] {
            stale.append(screen.name)
        }
        return Result(passed: stale.isEmpty, staleScreens: stale.sorted(), skipped: false)
    }
}
