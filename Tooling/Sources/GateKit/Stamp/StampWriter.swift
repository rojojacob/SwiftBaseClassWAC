import Foundation

/// Updates the stamp for the screens that just passed, preserving the rest.
public struct StampWriter {
    private let hasher: ScreenHasher
    private let store: StampStoring

    public init(hasher: ScreenHasher, store: StampStoring) {
        self.hasher = hasher
        self.store = store
    }

    public func record(_ screens: [Screen]) throws {
        guard !screens.isEmpty else { return }
        var updates: [String: String] = [:]
        for screen in screens {
            updates[screen.name] = try hasher.hash(screen)
        }
        var stamp = store.load()
        stamp.merge(updates)
        store.save(stamp)
    }
}
