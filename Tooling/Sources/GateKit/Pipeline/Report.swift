public struct Report: Equatable, Sendable {
    public let results: [StageResult]

    public init(results: [StageResult]) {
        self.results = results
    }

    public var passed: Bool {
        results.allSatisfy(\.passed)
    }
}
