#!/bin/zsh
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift_tool="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
app="$root/.build/CodexUsageMonitor.app"

# Ship an optimized binary. A debug build is unoptimized, carries debug
# metadata, and is the wrong thing to hand a user or submit to Apple's notary
# service. Override with BUILD_CONFIGURATION=debug for local iteration.
configuration="${BUILD_CONFIGURATION:-release}"
products="$root/.build/$configuration"

DEVELOPER_DIR="$developer_dir" "$swift_tool" build -c "$configuration" --package-path "$root"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
install -m 755 "$products/CodexUsageMonitor" "$app/Contents/MacOS/CodexUsageMonitor"
install -m 644 "$root/Resources/Info.plist" "$app/Contents/Info.plist"
xcrun actool "$root/Resources/Assets.xcassets" \
  --compile "$app/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$app/Contents/Resources/AssetCatalogInfo.plist"

# Bundle the native Claude usage bridge as an app resource. This replaces the
# former Python bridge, so a shipped build no longer depends on the user having
# python3 installed. The installer copies this signed executable out to
# Application Support (stripping quarantine) before Claude Code execs it.
bridge_binary="$products/claude-usage-bridge"
bridge_resource="$app/Contents/Resources/ClaudeUsageBridge"
test -f "$bridge_binary"
rm -rf "$bridge_resource"
mkdir -p "$bridge_resource"
install -m 755 "$bridge_binary" "$bridge_resource/claude-usage-bridge"

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
#
# Nested code (the bundled bridge helper) must be signed BEFORE the app —
# code signing is applied inside-out, and notarization rejects an unsigned
# nested Mach-O.
identity="${CODESIGN_IDENTITY:-Developer ID Application}"
bridge_executable="$bridge_resource/claude-usage-bridge"
if codesign --force --options runtime --sign "$identity" \
     --identifier com.david.codex-usage-monitor.bridge "$bridge_executable" 2>/dev/null \
   && codesign --force --options runtime --sign "$identity" \
     --identifier com.david.codex-usage-monitor "$app" 2>/dev/null; then
  echo "Signed with: $identity"
else
  echo "WARNING: could not sign with '$identity'; falling back to ad-hoc." >&2
  echo "         Keychain 'Always Allow' will NOT survive rebuilds." >&2
  echo "         Set CODESIGN_IDENTITY to a valid identity to fix this." >&2
  codesign --force --sign - --identifier com.david.codex-usage-monitor.bridge "$bridge_executable"
  codesign --force --sign - --identifier com.david.codex-usage-monitor "$app"
fi

echo "Built $app"
