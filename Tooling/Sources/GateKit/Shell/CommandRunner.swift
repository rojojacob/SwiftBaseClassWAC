import Foundation

public struct ProcessResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var succeeded: Bool {
        exitCode == 0
    }
}

public protocol CommandRunner {
    func run(_ argv: [String], cwd: URL, env: [String: String]) throws -> ProcessResult
}

public extension CommandRunner {
    func run(_ argv: [String], cwd: URL) throws -> ProcessResult {
        try run(argv, cwd: cwd, env: ProcessInfo.processInfo.environment)
    }
}
