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
# Attempt the real signature directly rather than probing with
# `security find-identity` first — that call can block on its own Keychain
# prompt, which would make a present identity look absent.
identity="${CODESIGN_IDENTITY:-Developer ID Application}"
if codesign --force --options runtime --sign "$identity" \
     --identifier com.david.codex-usage-monitor "$app" 2>/dev/null; then
  echo "Signed with: $identity"
else
  echo "WARNING: could not sign with '$identity'; falling back to ad-hoc." >&2
  echo "         Keychain 'Always Allow' will NOT survive rebuilds." >&2
  echo "         Set CODESIGN_IDENTITY to a valid identity to fix this." >&2
  codesign --force --sign - --identifier com.david.codex-usage-monitor "$app"
fi

echo "Built $app"
