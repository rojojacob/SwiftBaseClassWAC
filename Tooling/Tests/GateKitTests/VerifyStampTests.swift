import Foundation
import Testing
@testable import GateKit

private func env(
    _ finder: FakeFileFinder,
    _ reader: FakeFileReader,
    _ store: FakeStampStore
) -> VerifyStamp {
    VerifyStamp(
        screens: { [Screen(
            name: "Posts",
            codePath: "App/App/Features/Posts",
            unitTestClasses: [],
            uiTestClasses: []
        )] },
        hasher: ScreenHasher(
            finder: finder,
            reader: reader,
            repoRoot: URL(fileURLWithPath: "/repo")
        ),
        store: store
    )
}

@Test func verifyPassesWhenHashMatchesStamp() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let verifier = env(finder, reader, store)
    // Stamp the current content, then verify against it.
    try StampWriter(hasher: verifier.hasher, store: store).record(verifier.screens())

    let result = try verifier.run(skip: false)
    #expect(result.passed)
    #expect(result.staleScreens.isEmpty)
}

@Test func verifyFailsAndNamesStaleScreens() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let store = FakeStampStore()
    let verifier = env(finder, reader, store)
    try StampWriter(hasher: verifier.hasher, store: store).record(verifier.screens())

    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("EDITED".utf8)
    let result = try verifier.run(skip: false)
    #expect(result.passed == false)
    #expect(result.staleScreens == ["Posts"])
}

@Test func verifyTreatsNeverStampedScreenAsStale() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let result = try env(finder, reader, FakeStampStore()).run(skip: false)
    #expect(result.passed == false)
    #expect(result.staleScreens == ["Posts"])
}

@Test func skipShortCircuitsToPass() throws {
    let result = try env(FakeFileFinder(), FakeFileReader(), FakeStampStore()).run(skip: true)
    #expect(result.passed)
    #expect(result.skipped)
}
