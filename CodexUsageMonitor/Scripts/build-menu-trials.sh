#!/bin/zsh
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# Use the normal build/signing path; never alter identity or bundle identifiers.
bash "$root/Scripts/build-app.sh"
source_app="$root/.build/CodexUsageMonitor.app"
output="$root/.build/Menu Presentation Trials"
identity="${CODESIGN_IDENTITY:-Developer ID Application}"
mkdir -p "$output"

mode=panel
for data in live demo; do
    title="Panel ${(C)data}"
    destination="$output/$title.app"
    # ditto updates only this generated artifact; no installed application moves.
    ditto "$source_app" "$destination"
    plist="$destination/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :MenuPresentationTrialMode' "$plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :MenuPresentationTrialMode string $mode" "$plist"
    /usr/libexec/PlistBuddy -c 'Delete :MenuPresentationFixtures' "$plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :MenuPresentationFixtures bool $([[ $data == demo ]] && echo true || echo false)" "$plist"
    # Require the stable signing identity for these user-facing trial builds.
    codesign --force --options runtime --sign "$identity" \
      --identifier com.david.codex-usage-monitor "$destination"
    codesign --verify --deep --strict "$destination"
done
rm -rf "$output/Popover Live.app" "$output/Popover Demo.app"
cat > "$output/README.txt" <<'TXT'
CONTENT-FITTED MENU PANEL (ADR 0004 prototype)

Quit the currently running Agent Monitor before opening Panel Live. Run one
build at a time. Your installed app is not replaced.

Panel Live.app  Real usage in the content-fitted panel. Shares your normal
                preferences and provider state.
Panel Demo.app  Synthetic states only. Next state replays confirmed,
                refreshing, cached failure, repeated failure, unavailable and
                recovery. Account actions are inert; Quit works.

Record at 60 fps (QuickTime) and step through frames: switch providers,
open then immediately click a tab, use Next state, scroll the tall state,
click outside the menu, press Escape. Look for moving tabs or header,
duplicated text, a second background, a clipped footer or a stale shadow.
TXT
printf 'Built trial apps in %s\n' "$output"
