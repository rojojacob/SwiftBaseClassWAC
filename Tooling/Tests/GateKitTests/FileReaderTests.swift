import Foundation
import Testing
@testable import GateKit

@Test func fakeReaderReturnsStoredContentsAndExistence() throws {
    let reader = FakeFileReader()
    reader.filesByPath["/repo/A.swift"] = Data("struct A {}".utf8)
    #expect(reader.exists("/repo/A.swift"))
    #expect(reader.exists("/repo/missing.swift") == false)
    #expect(try reader.contents(of: "/repo/A.swift") == Data("struct A {}".utf8))
}

@Test func fakeReaderThrowsForMissingFile() {
    #expect(throws: (any Error).self) {
        _ = try FakeFileReader().contents(of: "/nope.swift")
    }
}
