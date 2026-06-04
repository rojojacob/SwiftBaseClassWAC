import Foundation
import Testing
@testable import GateKit

private let sampleJSON = """
[
  {"character":13,"file":"/repo/App/AView.swift","line":2,"reason":"Force tries should be avoided",
   "rule_id":"force_try","severity":"Error","type":"Force Try"},
  {"character":1,"file":"/repo/App/BView.swift","line":9,"reason":"Prefer isEmpty",
   "rule_id":"empty_count","severity":"Warning","type":"Empty Count"},
  {"character":1,"file":"/repo/App/CView.swift","line":4,"reason":"Type body too long",
   "rule_id":"type_body_length","severity":"Error","type":"Type Body Length"},
  {"character":1,"file":"/repo/App/Info.swift","reason":"Missing header",
   "rule_id":"file_header","severity":"Warning","type":"File Header"}
]
"""

@Test func parsesSwiftLintJSONIntoFindings() throws {
    let findings = try SwiftLintJSON.findings(fromJSON: Data(sampleJSON.utf8), repoRoot: "/repo")
    #expect(findings.count == 4)
    let forceTry = try #require(findings.first { $0.ruleID == "force_try" })
    #expect(forceTry.severity == .critical) // safety rule escalated
    #expect(forceTry.file == "App/AView.swift") // path made repo-relative
    #expect(forceTry.line == 2)
    #expect(forceTry.fix.isEmpty == false) // has a fix hint
    let emptyCount = try #require(findings.first { $0.ruleID == "empty_count" })
    #expect(emptyCount.severity == .medium) // warning → medium
}

@Test func nonCriticalErrorMapsToHigh() throws {
    let findings = try SwiftLintJSON.findings(fromJSON: Data(sampleJSON.utf8), repoRoot: "/repo")
    let bodyLength = try #require(findings.first { $0.ruleID == "type_body_length" })
    #expect(bodyLength.severity == .high) // non-safety Error → high
}

@Test func rowWithoutLineDecodesToNil() throws {
    let findings = try SwiftLintJSON.findings(fromJSON: Data(sampleJSON.utf8), repoRoot: "/repo")
    let fileHeader = try #require(findings.first { $0.ruleID == "file_header" })
    #expect(fileHeader.line == nil) // file-level rule omits "line"
}

@Test func emptyRepoRootLeavesPathsIntact() throws {
    let findings = try SwiftLintJSON.findings(fromJSON: Data(sampleJSON.utf8), repoRoot: "")
    let forceTry = try #require(findings.first { $0.ruleID == "force_try" })
    #expect(forceTry.file == "/repo/App/AView.swift") // not corrupted to "repo/App/AView.swift"
}

@Test func emptyJSONArrayYieldsNoFindings() throws {
    #expect(try SwiftLintJSON.findings(fromJSON: Data("[]".utf8), repoRoot: "/repo").isEmpty)
}
