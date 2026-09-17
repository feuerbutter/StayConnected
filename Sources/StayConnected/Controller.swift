import AppKit
import StayConnectedCore

struct ControllerSnapshot {
    let controlState: PersistentControlState
    let vpnState: VPNConnectionState
    let providers: [VPNProvider]
    let busy: Bool
    let message: String?
}

final class Controller: NSObject {
    var onSnapshot: ((ControllerSnapshot) -> Void)?
    private let store = ControlStateStore()
    private let worker = DispatchQueue(label: "io.github.stayconnected.worker")
    private var timer: Timer?
    private var state = PersistentControlState(mode: .paused)
    private var providers: [VPNProvider] = []
    private var vpnState: VPNConnectionState = .unknown
    private var busy = false
    private var attempt = 0
    private var nextAttempt = Date.distantPast
    private var message: String?

    func start() {
        do { state = try store.load() }
        catch { message = "Could not read saved settings; reconnect is paused." }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    func select(_ id: String) {
        guard providers.contains(where: { $0.id == id }), id != state.selectedProviderID,
              ProviderSelection.canSelect(currentID: state.selectedProviderID, providers: providers, state: vpnState, busy: busy) else { return }
        var updated = PersistentControlState(mode: .paused)
        updated.selectedProviderID = id
        guard save(updated) else { return }
        vpnState = .unknown
        attempt = 0
        nextAttempt = .distantPast
        poll()
    }

    func toggle() {
        guard !busy, let id = state.selectedProviderID,
              providers.contains(where: { $0.id == id }) else { return }
        var updated = state
        updated.mode = state.mode == .armed ? .paused : .armed
        updated.manualStopPending = updated.mode == .paused
        guard save(updated) else { return }
        attempt = 0
        nextAttempt = .distantPast
        poll()
    }

    func retryNow() {
        guard state.mode == .armed else { return }
        nextAttempt = .distantPast
        poll()
    }

    @objc private func wake() {
        nextAttempt = .distantPast
        poll()
    }

    func poll() {
        guard !busy else { return }
        busy = true
        publish()
        let id = state.selectedProviderID
        worker.async { [weak self] in
            let available = VPNService.providers()
            let present = available?.contains { $0.id == id } == true
            let observed = present ? VPNService.connectionState(providerID: id!) : .unknown
            let online = VPNService.internetAvailable()
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                guard let available else {
                    self.vpnState = .unknown
                    self.message = "VPN profile query failed; waiting to retry."
                    self.publish()
                    return
                }
                self.providers = available
                self.vpnState = observed
                self.message = nil
                guard present else { self.publish(); return }
                self.observe(online: online)
            }
        }
    }

    private func observe(online: Bool) {
        if state.mode == .armed && vpnState == .connected { attempt = 0; nextAttempt = .distantPast }
        let action = DecisionEngine.action(controlState: state, vpnState: vpnState,
                                           internetAvailable: online, retryReady: Date() >= nextAttempt)
        switch action {
        case .connect, .disconnect:
            // Bound both start and stop retries, including failures.
            if Date() >= nextAttempt { command(connect: action == .connect) }
        case .completePause:
            var updated = state
            updated.manualStopPending = false
            _ = save(updated)
        case .rearm:
            var updated = state
            updated.mode = .armed
            _ = save(updated)
        case .none: break
        }
        publish()
    }

    private func command(connect: Bool) {
        guard let id = state.selectedProviderID else { return }
        busy = true
        nextAttempt = Date().addingTimeInterval(connect ? RetryPolicy.delay(afterAttempt: attempt) : 5)
        if connect { attempt += 1 }
        worker.async { [weak self] in
            let result = connect ? VPNService.start(providerID: id) : VPNService.stop(providerID: id)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                // Invalidate the pre-command observation before re-enabling selection.
                self.vpnState = result.exitCode == 0 ? (connect ? .connecting : .disconnecting) : .unknown
                if result.exitCode != 0 {
                    self.message = "VPN command failed (\(result.exitCode)); check VPN Settings."
                }
                // Log exit status only: system diagnostics can contain profile details.
                AgentLog.write("VPN \(connect ? "start" : "stop") exit=\(result.exitCode)")
                self.publish()
            }
        }
    }

    @discardableResult private func save(_ updated: PersistentControlState) -> Bool {
        var updated = updated
        updated.updatedAt = Date()
        do { try store.save(updated); state = updated; message = nil; return true }
        catch { message = "Could not save settings; action cancelled."; publish(); return false }
    }

    private func publish() {
        onSnapshot?(ControllerSnapshot(controlState: state, vpnState: vpnState,
                                        providers: providers, busy: busy, message: message))
    }
}
