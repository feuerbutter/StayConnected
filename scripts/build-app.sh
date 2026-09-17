#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
/usr/bin/swift build --package-path "$project_root" -c release --product StayConnected
bundle="$project_root/.build/StayConnected.app"
/usr/bin/install -d "$bundle/Contents/MacOS"
/usr/bin/install -m 0755 "$project_root/.build/release/StayConnected" "$bundle/Contents/MacOS/StayConnected"
/usr/bin/install -m 0644 "$project_root/Resources/Info.plist" "$bundle/Contents/Info.plist"
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$bundle"
echo "Built $bundle"
