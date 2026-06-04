import Foundation

public struct SystemCommandRunner: CommandRunner {
    public init() {}

    public func run(_ argv: [String], cwd: URL, env: [String: String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = argv
        process.currentDirectoryURL = cwd
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        // Read both pipes concurrently so a full stderr buffer can't deadlock
        // a blocked stdout read (and vice versa).
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "gate.command.read", attributes: .concurrent)
        let outBox = DataBox()
        let errBox = DataBox()
        queue.async(group: group) { outBox.value = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errBox.value = errPipe.fileHandleForReading.readDataToEndOfFile() }
        process.waitUntilExit()
        group.wait()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(bytes: outBox.value, encoding: .utf8) ?? "",
            stderr: String(bytes: errBox.value, encoding: .utf8) ?? ""
        )
    }
}

private final class DataBox {
    var value = Data()
}
