import Foundation
@testable import GateKit

final class FakeCommandRunner: CommandRunner {
    private struct Stub {
        let needle: String
        let result: ProcessResult
    }

    private(set) var calls: [[String]] = []
    private var stubs: [Stub] = []
    var defaultResult = ProcessResult(exitCode: 0, stdout: "", stderr: "")

    func stub(whenContains needle: String, result: ProcessResult) {
        stubs.append(Stub(needle: needle, result: result))
    }

    func run(_ argv: [String], cwd _: URL, env _: [String: String]) throws -> ProcessResult {
        calls.append(argv)
        for stub in stubs where argv.contains(where: { $0.contains(stub.needle) }) {
            return stub.result
        }
        return defaultResult
    }
}
