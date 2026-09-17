import Darwin
import Foundation

public struct CommandResult {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String
}

/// Bound subprocess waits and drain both pipes while the child runs.
public enum BoundedCommand {
    public static func run(executable: String, arguments: [String], timeout: TimeInterval = 10) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: 127, standardOutput: "", standardError: error.localizedDescription)
        }

        // Read concurrently: waiting for exit first can deadlock on a full pipe.
        let output = PipeReader(outputPipe.fileHandleForReading)
        let errors = PipeReader(errorPipe.fileHandleForReading)
        let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 1)
            }
        }
        let stdout = output.text()
        let stderr = errors.text()
        return CommandResult(
            exitCode: timedOut ? 124 : process.terminationStatus,
            standardOutput: stdout,
            standardError: timedOut ? "Command timed out after \(timeout) seconds. \(stderr)" : stderr
        )
    }
}

private final class PipeReader {
    private let finished = DispatchSemaphore(value: 0)
    private var data = Data()

    init(_ handle: FileHandle) {
        DispatchQueue.global().async {
            self.data = handle.readDataToEndOfFile()
            self.finished.signal()
        }
    }

    func text() -> String {
        // scutil has no children; a bounded read also avoids retaining a stuck worker.
        guard finished.wait(timeout: .now() + 1) == .success else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
