public struct Screen: Equatable, Hashable, Sendable {
    public let name: String
    public let codePath: String
    public let unitTestClasses: [String]
    public let uiTestClasses: [String]
    /// Absolute paths of the screen's unit test files (distinct from the class
    /// names above) — used by `ScreenHasher` to hash the screen's tests.
    public let unitTestFiles: [String]
    /// Absolute paths of the screen's UI test files (see `unitTestFiles`).
    public let uiTestFiles: [String]

    public init(
        name: String,
        codePath: String,
        unitTestClasses: [String],
        uiTestClasses: [String],
        unitTestFiles: [String] = [],
        uiTestFiles: [String] = []
    ) {
        self.name = name
        self.codePath = codePath
        self.unitTestClasses = unitTestClasses
        self.uiTestClasses = uiTestClasses
        self.unitTestFiles = unitTestFiles
        self.uiTestFiles = uiTestFiles
    }
}
