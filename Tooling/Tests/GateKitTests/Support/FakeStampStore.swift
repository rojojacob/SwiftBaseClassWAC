@testable import GateKit

final class FakeStampStore: StampStoring {
    private(set) var saved: [Stamp] = []
    var current = Stamp(hashes: [:])

    func load() -> Stamp {
        current
    }

    func save(_ stamp: Stamp) {
        current = stamp
        saved.append(stamp)
    }
}
