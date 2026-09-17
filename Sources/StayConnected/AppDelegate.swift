import AppKit
import StayConnectedCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let controller = Controller()
    private let providerMenu = NSMenu()
    private let connection = NSMenuItem(title: "Choose a VPN provider to begin", action: nil, keyEquivalent: "")
    private let mode = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let detail = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggle = NSMenuItem(title: "Turn VPN On and Keep It Connected", action: #selector(toggleMode), keyEquivalent: "")
    private let retry = NSMenuItem(title: "Reconnect Now", action: #selector(retryNow), keyEquivalent: "r")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let menu = NSMenu()
        menu.autoenablesItems = false
        providerMenu.autoenablesItems = false
        [connection, mode, detail].forEach { $0.isEnabled = false; menu.addItem($0) }
        menu.addItem(.separator())
        let selector = NSMenuItem(title: "VPN Provider", action: nil, keyEquivalent: "")
        selector.submenu = providerMenu
        menu.addItem(selector)
        for item in [toggle, retry] { item.target = self; menu.addItem(item) }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Open VPN Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        statusItem.menu = menu
        controller.onSnapshot = { [weak self] in self?.render($0) }
        controller.start()
    }

    private func render(_ snapshot: ControllerSnapshot) {
        let selected = snapshot.providers.first { $0.id == snapshot.controlState.selectedProviderID }
        connection.title = selected.map { "\($0.name): \(snapshot.vpnState.rawValue.capitalized)" }
            ?? (snapshot.controlState.selectedProviderID == nil ? "Choose a VPN provider to begin" : "Selected VPN profile is unavailable")
        mode.title = snapshot.controlState.mode == .armed ? "Automatic reconnect: On" : "Automatic reconnect: Paused"
        detail.title = snapshot.message ?? (snapshot.providers.isEmpty ? "Add a supported VPN in System Settings" : "Turn VPN off before switching providers")
        let canSelect = ProviderSelection.canSelect(currentID: snapshot.controlState.selectedProviderID,
            providers: snapshot.providers, state: snapshot.vpnState, busy: snapshot.busy)
        // Rebuild only when the list changes; keep an open submenu stable during polling.
        if providerMenu.items.map({ $0.representedObject as? String }) != snapshot.providers.map({ Optional($0.id) }) {
            providerMenu.removeAllItems()
            for provider in snapshot.providers {
                let duplicate = snapshot.providers.filter { $0.name == provider.name }.count > 1
                let label = duplicate ? "\(provider.name) (\(provider.id))" : provider.name
                let item = NSMenuItem(title: label, action: #selector(selectProvider(_:)), keyEquivalent: "")
                item.representedObject = provider.id
                item.target = self
                providerMenu.addItem(item)
            }
        }
        for item in providerMenu.items {
            item.state = item.representedObject as? String == snapshot.controlState.selectedProviderID ? .on : .off
            item.isEnabled = canSelect
        }
        toggle.title = snapshot.controlState.mode == .armed ? "Turn VPN Off Until I Turn It On" : "Turn VPN On and Keep It Connected"
        toggle.isEnabled = selected != nil && !snapshot.busy
        retry.isEnabled = selected != nil && !snapshot.busy && snapshot.controlState.mode == .armed && snapshot.vpnState == .disconnected
        let symbol = selected == nil ? "shield" : snapshot.controlState.mode == .paused ? "shield.slash" : snapshot.vpnState == .connected ? "checkmark.shield.fill" : "arrow.triangle.2.circlepath.circle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: connection.title)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "StayConnected — \(connection.title)"
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { controller.select(id) }
    }
    @objc private func toggleMode() { controller.toggle() }
    @objc private func retryNow() { controller.retryNow() }
    @objc private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension?VPN") {
            NSWorkspace.shared.open(url)
        }
    }
}
