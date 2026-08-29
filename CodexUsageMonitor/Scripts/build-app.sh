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
# Remove the legacy nested helper from incremental app bundles. The current
# package ships one Mach-O; leaving a prior build's resource behind would make
# packaging depend on local build history.
rm -rf "$app/Contents/Resources/ClaudeUsageBridge"
install -m 755 "$products/CodexUsageMonitor" "$app/Contents/MacOS/CodexUsageMonitor"
install -m 644 "$root/Resources/Info.plist" "$app/Contents/Info.plist"
# `--app-icon` tags AppIcon as the icon inside the compiled catalog, which is
# what CFBundleIconName resolves through.
xcrun actool "$root/Resources/Assets.xcassets" \
  --compile "$app/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$app/Contents/Resources/AssetCatalogInfo.plist"

# Build the .icns from the same PNGs rather than keeping the one actool writes.
#
# Finder, Get Info, and notification banners read the file CFBundleIconFile
# names, not the catalog — and this app is LSUIElement, so those surfaces are
# the *only* places its icon is ever seen. actool's convenience .icns carries
# only 16, 32, 128, and 256 pixel representations, which leaves Get Info
# upscaling a 256 into a 512-point well. iconutil round-trips all ten.
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
cp "$root/Resources/Assets.xcassets/AppIcon.appiconset/"*.png "$iconset"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$iconset")"

# A menu-bar-only app shows no Dock icon, so a missing or generic icon stays
# invisible until a user opens Get Info. Fail the build instead.
test -s "$app/Contents/Resources/AppIcon.icns"

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
# prompt, which would make a present identity look absent. A signing command can
# still return success for an identity macOS cannot validate, so accept it only
# after strict verification of the completed bundle.
#
identity="${CODESIGN_IDENTITY:-Developer ID Application}"
if codesign --force --options runtime --sign "$identity" \
     --identifier com.david.codex-usage-monitor "$app" 2>/dev/null \
   && codesign --verify --deep --strict "$app" 2>/dev/null; then
  echo "Signed with: $identity"
else
  echo "WARNING: could not create a valid '$identity' signature; falling back to ad-hoc." >&2
  echo "         Keychain 'Always Allow' will NOT survive rebuilds." >&2
  echo "         Set CODESIGN_IDENTITY to a valid identity to fix this." >&2
  codesign --force --sign - --identifier com.david.codex-usage-monitor "$app"
  codesign --verify --deep --strict "$app"
fi

echo "Built $app"
