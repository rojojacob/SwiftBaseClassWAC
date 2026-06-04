public struct Screen: Equatable, Hashable, Sendable {
    public let name: String
    public let codePath: String
    public let unitTestClasses: [String]
    public let uiTestClasses: [String]

    public init(name: String, codePath: String, unitTestClasses: [String], uiTestClasses: [String]) {
        self.name = name
        self.codePath = codePath
        self.unitTestClasses = unitTestClasses
        self.uiTestClasses = uiTestClasses
    }
}
