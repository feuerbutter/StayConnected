# Contributing

Use a focused branch and pull request. Describe the user-visible problem, changed behavior, and checks performed. Keep provider-specific adapters separate from the generic controller.

## Layout

- `Sources/StayConnectedCore`: persistent state, profile parsing, reconnect decisions, and bounded commands.
- `Sources/StayConnected`: macOS integration, menu-bar UI, and read-only diagnostics.
- `Tests/StayConnectedCoreTests`: framework-free checks for the state machine and known command-stall failure.
- `scripts`: build, per-user install, and recoverable uninstall.

## Before a pull request

```sh
swift run StayConnectedCoreChecks
swift build -c release
./scripts/build-app.sh
zsh -n scripts/build-app.sh scripts/install.sh scripts/uninstall.sh
```

Run manual integration tests only with a VPN you may disconnect. Check first launch, multiple profiles (including duplicate names), switching after disconnect, manual pause across restart, externally initiated reconnect, network loss, and sleep/wake. Report exactly which were exercised. Automated checks do not prove a provider's live behavior.

Do not commit VPN endpoints, credentials, profile exports, local service IDs, personal paths, screenshots with private details, logs, or state files. Use synthetic profiles in tests. Diagnostics printed by `--providers` and `--status` need redaction before sharing. Never request credentials in an issue.

Keep fixes small and test reconnect semantics, provider identity, and user controls. GitHub Actions performs the same core checks and release build on macOS.
