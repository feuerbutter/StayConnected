import Foundation

enum AgentLog {
    static func write(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("\(timestamp) \(message)")
        fflush(stdout)
    }
}
