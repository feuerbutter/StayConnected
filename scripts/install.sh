#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
"$project_root/scripts/build-app.sh"
app_bundle="$HOME/Applications/StayConnected.app"
launch_agent="$HOME/Library/LaunchAgents/io.github.stayconnected.agent.plist"
log_directory="$HOME/Library/Logs/StayConnected"
archive_root="$HOME/Library/Application Support/StayConnected/discarded/install-$(/bin/date -u +%Y%m%dT%H%M%SZ)-$$"
uid_value=$(/usr/bin/id -u)
# Generate a real plist with escaped paths for this user; never ship a personal plist.
prepared_plist="$project_root/.build/io.github.stayconnected.agent.plist"
/usr/bin/plutil -create xml1 "$prepared_plist"
/usr/bin/plutil -insert Label -string io.github.stayconnected.agent "$prepared_plist"
/usr/bin/plutil -insert ProgramArguments -array "$prepared_plist"
/usr/bin/plutil -insert ProgramArguments.0 -string "$app_bundle/Contents/MacOS/StayConnected" "$prepared_plist"
/usr/bin/plutil -insert ProgramArguments.1 -string --agent "$prepared_plist"
/usr/bin/plutil -insert RunAtLoad -bool YES "$prepared_plist"
/usr/bin/plutil -insert KeepAlive -bool YES "$prepared_plist"
/usr/bin/plutil -insert LimitLoadToSessionType -string Aqua "$prepared_plist"
/usr/bin/plutil -insert ThrottleInterval -integer 10 "$prepared_plist"
/usr/bin/plutil -insert StandardOutPath -string "$log_directory/agent.log" "$prepared_plist"
/usr/bin/plutil -insert StandardErrorPath -string "$log_directory/agent-error.log" "$prepared_plist"
/usr/bin/plutil -lint "$prepared_plist"
/bin/launchctl bootout "gui/$uid_value/io.github.stayconnected.agent" 2>/dev/null || true
/bin/mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$log_directory"
if [[ -e "$app_bundle" || -e "$launch_agent" ]]; then
    /bin/mkdir -p "$archive_root"
    [[ ! -e "$app_bundle" ]] || /bin/mv "$app_bundle" "$archive_root/StayConnected.app"
    [[ ! -e "$launch_agent" ]] || /bin/mv "$launch_agent" "$archive_root/io.github.stayconnected.agent.plist"
    echo "Previous installation retained at $archive_root"
fi
/usr/bin/ditto "$project_root/.build/StayConnected.app" "$app_bundle"
/usr/bin/install -m 0644 "$prepared_plist" "$launch_agent"
/bin/launchctl bootstrap "gui/$uid_value" "$launch_agent"
/bin/launchctl print "gui/$uid_value/io.github.stayconnected.agent" >/dev/null
echo "Installed StayConnected. Choose VPN Provider in the shield menu, then turn reconnect on."
echo "Existing StayConnected selections and manual pauses are preserved during upgrades."
