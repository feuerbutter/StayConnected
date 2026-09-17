import Foundation

public struct VPNProvider: Equatable {
    public let id: String
    public let name: String

    /// Parse only enabled services exposed by `scutil --nc list`.
    public static func parse(_ listing: String) -> [VPNProvider] {
        let pattern = #"^\s*\*\s+\([^)]*\)\s+([0-9A-Fa-f-]{36})\s+.*?\"(.*)\"\s+\[.*\]\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return listing.components(separatedBy: .newlines).compactMap { line in
            guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let idRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line) else { return nil }
            let id = String(line[idRange])
            guard UUID(uuidString: id) != nil else { return nil }
            return VPNProvider(id: id, name: String(line[nameRange]))
        }
    }
}

public enum ProviderSelection {
    public static func canSelect(currentID: String?, providers: [VPNProvider], state: VPNConnectionState, busy: Bool) -> Bool {
        guard !busy else { return false }
        return currentID == nil || !providers.contains { $0.id == currentID } || state == .disconnected
    }
}
