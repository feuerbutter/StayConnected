#!/bin/zsh
set -euo pipefail
uid_value=$(/usr/bin/id -u)
archive_root="$HOME/Library/Application Support/StayConnected-discarded/uninstalled-$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$"
/bin/launchctl bootout "gui/$uid_value/io.github.stayconnected.agent" 2>/dev/null || true
/bin/mkdir -p "$archive_root"
for item in "$HOME/Applications/StayConnected.app" "$HOME/Library/LaunchAgents/io.github.stayconnected.agent.plist" "$HOME/Library/Application Support/StayConnected" "$HOME/Library/Logs/StayConnected"; do
    if [[ -e "$item" ]]; then
        # Keep state and logs in distinct destinations.
        case "$item" in
            */Logs/*) destination=logs ;;
            */Application\ Support/*) destination=settings ;;
            *) destination="${item:t}" ;;
        esac
        /bin/mv "$item" "$archive_root/$destination"
    fi
done
echo "Installation archived at $archive_root"
echo "The current VPN connection was not stopped."
