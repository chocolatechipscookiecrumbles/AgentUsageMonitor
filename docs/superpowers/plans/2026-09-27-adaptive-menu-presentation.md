# Adaptive Menu Presentation Implementation Plan

> **Closed — rejected 2026-09-28.** The user reported that neither trial fixed the defect and both recreated the switch-tab artifact. The remaining tasks below will not be completed. The bounded-viewport correction and renderer split were kept and committed; the panel/popover trial hosts, fixture replay and `build-menu-trials.sh` are archived on the local branch `archive/rejected-menu-trials-2026-09-28`. Diagnosis: [Trial rejection and diagnosis](../../development/provider-switch-diagnostic-results.md#trial-rejection-and-diagnosis--2026-09-28). Successor: [content-fitted menu panel plan](2026-09-29-content-fitted-menu-panel.md).

**Goal:** Compare the current-looking panel with a native popover, using the same real menu content, while repairing the failure-state scroll boundary.
**Architecture:** Keep production presentation until comparison acceptance. Trial hosts own one persistent hosting controller, an adaptive bounded provider viewport, and their native window geometry.
**Tech stack:** Swift 6.2, macOS 14+, SwiftUI, AppKit, existing SwiftPM and signed-app build.

## Agreed decisions

- Preserve the 340-point content width and current cards, charts, tabs and commands.
- Deliver both custom NSPanel and native NSPopover trials before choosing a production host.
- Resize to content immediately, without animation, anchored below the status item; scroll only overflow.
- Provider selection starts at the top; same-provider updates preserve position where possible.
- Use the status item's current screen; retain keyboard, accessibility and system appearance behavior.
- Fixture mode must not construct live monitoring dependencies or access real settings, accounts or credentials.
- Normal launch keeps the current presentation during comparison. No push or PR; commit only this task's delta on the current branch as requested.

## Tasks and evidence

- [x] Reproduce the fixed-size scroll-view overflow with a focused native layout regression; prove red before correction.
- [x] Share bounded layout and actual provider renderers between live menu and inert fixtures.
- [x] Implement explicit `--menu-presentation=panel` / `--menu-presentation=popover` hosts and fixture replay.
- [x] Build signed comparison app and provide launchers without replacing the installed app.
- [x] Run focused regressions during implementation, full suite once at the end, and standards/spec review.
- [ ] Capture signed-app failures/recovery, switching, scrolling, dismissal and Settings actions. Record incomplete acceptance honestly.
- [ ] Commit task-only changes and hand off both trials for the user's selection. Production host migration remains gated on that selection.

## Acceptance matrix

Confirmed → refreshing → cached failure → repeated failure → recovery, unavailable without cache, shortest/tallest Claude and connect-only; long text, denied notification guidance, Token Monitor on/off. Verify fixed header/footer and reachable recovery controls. Record intermediate frames during 20 switches, not only settled screenshots. Check pointer, keyboard, VoiceOver, Light/Dark, short and multiple screens, app deactivation, outside-click pass-through, shortcuts and Settings destinations.

## Initial environment findings

- Baseline: `b98782f2081bf4359e799fd9f55075ff36a21006` on `feat/claude-passive-first`, with extensive pre-existing uncommitted work retained. Working-file baseline saved privately for task-only staging.
- `xcodebuild -list` cannot find an Xcode project/workspace/package in the package directory. No project or build settings will be generated to conceal that limitation. SwiftPM and signed-app verification remain required.
- Earlier Computer Use attempts timed out. Live acceptance is not established by source review or geometry tests.

## Verification — 2026-09-28

- `swift test --filter MenuViewportOverflowTests`: red with four viewport-bound assertions (800 pt native viewport in 637 pt allocation); green after explicit viewport sizing. Integrated focused run also passed.
- `swift test`: exit 0, 314 tests executed, 1 existing skip, 0 failures. The skipped glyph-opacity test reports the untracked Claude asset catalog is absent.
- `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' build`: exit 66; this SwiftPM-only directory has no Xcode project/workspace discoverable by xcodebuild. No project/settings changes were made to bypass it.
- Compiler warnings remain in existing ClaudeOAuthCredential code: deprecated `SecKeychainGetUserInteractionAllowed`, `SecKeychainSetUserInteractionAllowed`, and `SecKeychainCopyDefault`. Asset compilation also emits environment dyld/MediaToolbox symbol warnings.
- Standards and spec reviews found the detached Settings environment action, incorrect system-permission destination, and missing initial cached-failure fixture. All were corrected and re-reviewed. No remaining concrete code finding was reported.
- Settings dispatch now invokes the actual scene-installed application-menu command through public NSMenu APIs. Its live behavior is still subject to signed-app acceptance.
- Computer Use returned `timeoutReached` (-10005) for signed Panel Demo. The launch-created demo process was identified and terminated; the pre-existing user app was left running. No signed screenshot or interaction coverage is claimed.
- Pending visual acceptance: failure/recovery overlap in actual menu; intermediate frames during provider switches; scroll preservation/reset; Settings commands; dismissal/click-through; keyboard/VoiceOver; Light/Dark; short/multiple screens. Do not promote either trial host before this and the user's comparison.

## Delivered artifacts and commit boundary

`zsh CodexUsageMonitor/Scripts/build-menu-trials.sh` completed with exit 0 after
all review fixes. All four resulting app signatures passed `codesign --verify
--deep --strict` outside the sandbox. The build uses the existing Developer ID,
bundle identifier, entitlements, and deployment target. The installed app was
not replaced. Artifacts: `.build/Menu Presentation Trials/{Panel,Popover}
{Live,Demo}.app`, with a README explaining one-at-a-time use and demo replay.

The working-tree build and tests include pre-existing uncommitted Claude work.
An isolated copy of HEAD plus only this task's files fails to compile against
older Claude APIs (`isEnrolled`, `statusDetail`, header time input, and menu
height constants). Adding the immediate UI prerequisites reveals further
Connection/Quota/Settings migration dependencies. No user files or index entries
were changed by this experiment. A standalone task commit would therefore
require prior Claude migration changes, beyond the promised task-only scope.
The user has been asked whether to leave the prototype uncommitted or review
and commit those prerequisites separately first. No commit or push has occurred.
