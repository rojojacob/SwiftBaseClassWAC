import Foundation
import Testing
@testable import GateKit

@Test func writerStampsOnlyTheVerifiedScreens() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    store.current = Stamp(hashes: ["Counter": "keep"])
    let hasher = ScreenHasher(
        finder: finder,
        reader: reader,
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let writer = StampWriter(hasher: hasher, store: store)

    let posts = Screen(
        name: "Posts",
        codePath: "App/App/Features/Posts",
        unitTestClasses: [],
        uiTestClasses: []
    )
    try writer.record([posts])

    let saved = store.load()
    #expect(saved.hashes["Counter"] == "keep") // untouched screens preserved
    #expect(saved.hashes["Posts"]?.isEmpty == false) // verified screen stamped
}
