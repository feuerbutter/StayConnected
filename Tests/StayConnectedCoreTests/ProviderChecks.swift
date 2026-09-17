import Foundation
import StayConnectedCore

func runProviderChecks(_ runner: inout CheckRunner) {
    let a = "11111111-1111-1111-1111-111111111111"
    let b = "22222222-2222-2222-2222-222222222222"
    let listing = """
    Available network connection services in the current set (*=enabled):
    * (Connected)      \(a) IPSec              "Example VPN"                      [IPSec]
    * (Disconnected)   \(b) VPN (com.example.client) "Example VPN"                [VPN:com.example.client]
      (Disconnected)   33333333-3333-3333-3333-333333333333 IPSec "Disabled VPN" [IPSec]
    """
    let providers = VPNProvider.parse(listing)
    runner.expect(providers.count == 2, "discovers enabled native and plugin profiles only")
    runner.expect(providers.map(\.id) == [a, b], "duplicate names retain distinct service identities")
    runner.expect(providers.map(\.name) == ["Example VPN", "Example VPN"], "profile names are parsed without type suffixes")
    runner.expect(VPNProvider.parse("No services").isEmpty, "empty provider list is supported")
    runner.expect(ProviderSelection.canSelect(currentID: nil, providers: providers, state: .unknown, busy: false), "first launch allows explicit selection")
    runner.expect(!ProviderSelection.canSelect(currentID: a, providers: providers, state: .connected, busy: false), "cannot switch away from connected profile")
    runner.expect(!ProviderSelection.canSelect(currentID: a, providers: providers, state: .connecting, busy: false), "cannot switch during connection")
    runner.expect(!ProviderSelection.canSelect(currentID: a, providers: providers, state: .unknown, busy: false), "unknown status cannot authorize switching")
    runner.expect(ProviderSelection.canSelect(currentID: a, providers: providers, state: .disconnected, busy: false), "disconnected profile permits switching")
    runner.expect(!ProviderSelection.canSelect(currentID: a, providers: providers, state: .disconnected, busy: true), "in-flight command prevents switching")
    runner.expect(ProviderSelection.canSelect(currentID: a, providers: [], state: .unknown, busy: false), "removed profile permits choosing replacement")
    do {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = ControlStateStore(fileURL: location)
        let initial = try store.load()
        runner.expect(initial.selectedProviderID == nil, "first launch selects no provider")
        var state = PersistentControlState(mode: .paused)
        state.selectedProviderID = b
        try store.save(state)
        let reloaded = try store.load()
        runner.expect(reloaded.selectedProviderID == b && reloaded.mode == .paused, "selection and pause survive restart")
    } catch { runner.expect(false, "provider persistence: \(error)") }
}
