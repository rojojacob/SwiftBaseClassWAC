import Foundation
import Testing
@testable import GateKit

@Test func stampRoundTripsThroughFakeStore() {
    let store = FakeStampStore()
    store.save(Stamp(hashes: ["Posts": "abc", "Counter": "def"]))
    #expect(store.load().hashes["Posts"] == "abc")
    #expect(store.load().hashes["Counter"] == "def")
}

@Test func emptyStampWhenNothingSaved() {
    #expect(FakeStampStore().load().hashes.isEmpty)
}

@Test func mergingUpdatesOnlyTheGivenScreens() {
    var stamp = Stamp(hashes: ["Posts": "old", "Counter": "keep"])
    stamp.merge(["Posts": "new"])
    #expect(stamp.hashes["Posts"] == "new")
    #expect(stamp.hashes["Counter"] == "keep")
}
