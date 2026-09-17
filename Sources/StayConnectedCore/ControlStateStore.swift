import Foundation

public struct ControlStateStore {
    public let fileURL: URL

    public init(fileURL: URL = ControlStateStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StayConnected", isDirectory: true)
            .appendingPathComponent("control-state.json", isDirectory: false)
    }

    public func load() throws -> PersistentControlState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PersistentControlState(mode: .paused)
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistentControlState.self, from: data)
    }

    public func save(_ state: PersistentControlState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
