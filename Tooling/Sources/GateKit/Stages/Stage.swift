public enum StageID: String, Equatable, Sendable {
    case format
    case lint
    case test
}

public enum Outcome: Equatable, Sendable {
    case passed
    case failed
}

public struct Finding: Equatable, Sendable {
    public let file: String?
    public let line: Int?
    public let message: String

    public init(file: String? = nil, line: Int? = nil, message: String) {
        self.file = file
        self.line = line
        self.message = message
    }
}

public struct StageResult: Equatable, Sendable {
    public let stage: StageID
    public let outcome: Outcome
    public let findings: [Finding]
    public let summary: String

    public init(stage: StageID, outcome: Outcome, findings: [Finding], summary: String) {
        self.stage = stage
        self.outcome = outcome
        self.findings = findings
        self.summary = summary
    }

    public var passed: Bool {
        outcome == .passed
    }
}

public protocol Stage {
    var id: StageID { get }
    func run(_ scope: ResolvedScope, _ context: GateContext) throws -> StageResult
}
