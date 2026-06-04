import Foundation
import Testing
@testable import GateKit

private func screen(_ name: String, unit: [String], ui: [String]) -> Screen {
    Screen(
        name: name,
        codePath: "App/App/Features/\(name)",
        unitTestClasses: [],
        uiTestClasses: [],
        unitTestFiles: unit,
        uiTestFiles: ui
    )
}

@Test func hashIsStableForUnchangedContent() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("struct PostsView {}".utf8)
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("test".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let scr = screen("Posts", unit: ["/repo/u/PostsTests.swift"], ui: [])

    let h1 = try hasher.hash(scr)
    let h2 = try hasher.hash(scr)
    #expect(h1 == h2)
    #expect(h1.isEmpty == false)
}

@Test func hashChangesWhenAnyFileContentChanges() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/PostsView.swift"]
    let reader = FakeFileReader()
    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v1".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let scr = screen("Posts", unit: [], ui: [])
    let before = try hasher.hash(scr)

    reader.filesByPath["/repo/App/App/Features/Posts/PostsView.swift"] = Data("v2".utf8)
    let after = try hasher.hash(scr)
    #expect(before != after)
}

@Test func hashChangesWhenTestFileChanges() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = []
    let reader = FakeFileReader()
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("a".utf8)
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let scr = screen("Posts", unit: ["/repo/u/PostsTests.swift"], ui: [])
    let before = try hasher.hash(scr)
    reader.filesByPath["/repo/u/PostsTests.swift"] = Data("b".utf8)
    #expect(try hasher.hash(scr) != before)
}

@Test func hashChangesWhenSourceFileIsAdded() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/App/Features/Posts"] = []
    let reader = FakeFileReader()
    let hasher = ScreenHasher(finder: finder, reader: reader, repoRoot: URL(fileURLWithPath: "/repo"))
    let scr = screen("Posts", unit: [], ui: [])
    let before = try hasher.hash(scr)

    finder.filesByDirectory["/repo/App/App/Features/Posts"] = ["/repo/App/App/Features/Posts/NewView.swift"]
    reader.filesByPath["/repo/App/App/Features/Posts/NewView.swift"] = Data("struct NewView {}".utf8)
    #expect(try hasher.hash(scr) != before)
}
