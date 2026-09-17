import Foundation
import SystemConfiguration
import StayConnectedCore

enum VPNService {
    static func providers() -> [VPNProvider]? {
        let result = runScutil(["list"])
        guard result.exitCode == 0 else { return nil }
        return VPNProvider.parse(result.standardOutput)
    }

    static func connectionState(providerID: String) -> VPNConnectionState {
        let result = runScutil(["status", providerID])
        guard result.exitCode == 0 else { return .unknown }
        let line = result.standardOutput.split(whereSeparator: { $0.isNewline }).first?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return VPNConnectionState(rawValue: line) ?? .unknown
    }

    static func start(providerID: String) -> CommandResult { runScutil(["start", providerID]) }
    static func stop(providerID: String) -> CommandResult { runScutil(["stop", providerID]) }

    /// A default-route reachability hint; no provider hostname or probe traffic.
    static func internetAvailable() -> Bool {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        let reachability = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
        guard let reachability else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    private static func runScutil(_ arguments: [String]) -> CommandResult {
        BoundedCommand.run(executable: "/usr/sbin/scutil", arguments: ["--nc"] + arguments)
    }
}
