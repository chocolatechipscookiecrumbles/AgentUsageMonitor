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
xcrun actool "$root/Resources/Assets.xcassets" \
  --compile "$app/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$app/Contents/Resources/AssetCatalogInfo.plist"
# Sign with a stable identity, not ad-hoc.
#
# An ad-hoc signature (`--sign -`) has no certificate, so its designated
# requirement is pinned to the binary's cdhash — which changes on every build.
# Keychain ACL grants are keyed to that requirement, so "Always Allow" was
# silently invalidated by the next rebuild and the prompt returned every time.
# A Developer ID signature's requirement is identity-based and stable across
# rebuilds, so the grant persists.
#
# Override with CODESIGN_IDENTITY; falls back to ad-hoc when no identity is
# available (the grant will not stick in that case).
identity="${CODESIGN_IDENTITY:-Developer ID Application}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$identity"; then
  codesign --force --options runtime --sign "$identity" \
    --identifier com.david.codex-usage-monitor "$app"
  echo "Signed with: $identity"
else
  echo "WARNING: no '$identity' signing identity found; falling back to ad-hoc." >&2
  echo "         Keychain 'Always Allow' will NOT survive rebuilds." >&2
  codesign --force --sign - --identifier com.david.codex-usage-monitor "$app"
fi

echo "Built $app"
