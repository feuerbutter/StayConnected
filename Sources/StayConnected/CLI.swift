import Foundation
import StayConnectedCore

enum CLI {
    static func run(arguments: [String]) -> Int32 {
        guard arguments.count == 1 else { return help(code: 2) }
        switch arguments[0] {
        case "--providers":
            guard let providers = VPNService.providers() else {
                fputs("Could not query VPN profiles. Try System Settings.\n", stderr)
                return 1
            }
            for provider in providers { print("\(provider.id)\t\(provider.name)") }
            if providers.isEmpty { print("No supported VPN profiles found.") }
            return 0
        case "--status":
            do {
                let state = try ControlStateStore().load()
                print("controller=\(state.mode.rawValue)")
                print("provider_id=\(state.selectedProviderID ?? "not selected")")
                if let id = state.selectedProviderID {
                    print("vpn=\(VPNService.connectionState(providerID: id).rawValue)")
                }
                return 0
            } catch { fputs("Could not read controller settings.\n", stderr); return 1 }
        case "--help", "-h": return help(code: 0)
        default: return help(code: 2)
        }
    }
    private static func help(code: Int32) -> Int32 {
        print("""
        StayConnected — automatic recovery for macOS VPN profiles
          --agent       Run the menu-bar app (default)
          --providers   List supported local profiles and service IDs
          --status      Show saved selection and current VPN state
          --help        Show this help
        Choose a VPN Provider and turn reconnect on from the menu bar.
        Profile names and IDs printed by diagnostics are local information;
        redact them before sharing bug reports.
        """)
        return code
    }
}
