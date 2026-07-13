#!/bin/zsh
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift_tool="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
app="$root/.build/CodexUsageMonitor.app"

DEVELOPER_DIR="$developer_dir" "$swift_tool" build --package-path "$root"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
install -m 755 "$root/.build/debug/CodexUsageMonitor" "$app/Contents/MacOS/CodexUsageMonitor"
install -m 644 "$root/Resources/Info.plist" "$app/Contents/Info.plist"
codesign --force --sign - --identifier com.david.codex-usage-monitor "$app"

echo "Built $app"
