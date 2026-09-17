# StayConnected

A small macOS menu-bar app that reconnects your selected VPN after an unexpected drop, with a persistent manual pause when you want it off.

## What it does

- **VPN provider selector:** choose among enabled VPN profiles already configured in macOS. Selection is remembered by service ID, including when names are duplicated or renamed.
- **Automatic recovery:** checks every three seconds, checks after wake, and retries after 5, 15, 30, 60, 120, then 300 seconds.
- **Intentional off:** “Turn VPN Off Until I Turn It On” disconnects the selected profile and saves the pause across restarts.
- **Login startup:** a per-user LaunchAgent keeps the menu-bar app running.
- **No bundled provider configuration:** credentials and server settings stay in macOS and Keychain. No analytics, account, or third-party dependencies.

## Requirements and compatibility

macOS 13 or newer and Apple's Xcode Command Line Tools (Swift 5.9 or newer). Run `xcode-select --install` if the tools are missing.

StayConnected controls **enabled profiles listed by `/usr/sbin/scutil --nc list`**. It does not create VPN profiles, store passwords, implement VPN protocols, or replace a provider's client. VPNs managed exclusively by apps such as WireGuard, OpenVPN clients, or vendor-specific clients are not automatically supported. A profile appearing in the list is necessary, but its ability to connect without interactive authentication also depends on macOS and the provider. Test your profile in System Settings first.

One profile is managed at a time. This is a manual provider selector, not automatic failover between accounts. Disconnect the selected VPN through StayConnected before choosing another provider. Other profiles are left alone. Avoid running another auto-reconnect controller for the same profile.

## Install

```sh
git clone https://github.com/feuerbutter/StayConnected.git
cd StayConnected
./scripts/install.sh
```

The source build is locally ad-hoc signed; it is not a notarized downloadable release. No `sudo` is needed. The installer uses your home directory and works from any checkout location.

1. Open the shield icon in the menu bar.
2. Open **VPN Provider** and select a profile. If none appear, configure and enable a supported VPN in System Settings.
3. Choose **Turn VPN On and Keep It Connected**.
4. To switch, choose **Turn VPN Off Until I Turn It On**, wait for Disconnected, select the next provider, then turn it on.

A fresh install has no selected profile and makes no connection changes. An upgrade preserves the saved provider and pause/reconnect mode. If a profile disappears, the app waits for your selection rather than choosing another automatically. Provider switching and controls are briefly disabled while a bounded system command is in progress.

## Manual pause and reconnect behavior

Use the app's Off action when you intend to stay disconnected. Disconnecting from System Settings while automatic reconnect is on is treated as a drop and can reconnect. Conversely, manually connecting the selected VPN in System Settings after a completed pause re-enables automatic recovery.

System commands have a ten-second deadline with bounded process cleanup, so a stalled macOS status command cannot indefinitely freeze later operations. An unknown status causes the app to wait. Default-route reachability is a network hint, not proof of Internet access or a healthy VPN tunnel; captive portals and a connected-but-unusable VPN need manual diagnosis. This app is not a kill switch and does not prevent traffic outside the VPN.

## Inspect and build

```sh
swift run StayConnected --providers
swift run StayConnected --status
swift run StayConnectedCoreChecks
./scripts/build-app.sh
```

The last command produces `.build/StayConnected.app` without installing or launching it. For development, `swift run StayConnected --agent` runs the menu-bar app. Stop a development instance before starting an installed instance.

Profile names and IDs shown by diagnostics are private local information. Redact them before posting an issue.

## Local files and uninstall

| Item | Location |
| --- | --- |
| Application | `~/Applications/StayConnected.app` |
| Login agent | `~/Library/LaunchAgents/io.github.stayconnected.agent.plist` |
| Selection and pause state | `~/Library/Application Support/StayConnected/control-state.json` |
| Logs | `~/Library/Logs/StayConnected/` |

The repository excludes local state, logs, builds, and VPN configuration files. Installer updates retain prior app/agent files under the local support directory's `discarded/` folder. Logs contain timestamps, operation names, and exit codes; system-command diagnostics are not logged. Logs are not currently rotated.

```sh
./scripts/uninstall.sh
```

Uninstall unloads the login agent and moves installed files, state, and logs into `~/Library/Application Support/StayConnected-discarded/`. It does not stop your VPN or remove its macOS profile. You can remove the archive yourself when no longer needed.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks, review guidance, and privacy expectations. GitHub Actions builds on macOS and runs the framework-free checks on every push and pull request. Use Issues for bugs and enhancements; the templates request reproducible, redacted reports. Changes are tracked in [CHANGELOG.md](CHANGELOG.md).

MIT licensed; see [LICENSE](LICENSE).
