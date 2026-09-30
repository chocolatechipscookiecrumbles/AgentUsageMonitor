# Settings Destination Switch: Retained Pages

> **For agentic workers:** Prototype candidate 1 of the comparison that `AGENTS.md` requires before another Settings destination-switch repair. Acceptance is a signed-app 60 fps recording, not tests or source review.

**Goal:** Stop the one-to-two-frame duplicated and displaced text across the whole Settings window when switching destinations, observed most clearly between General and Notifications.

**Background:** see *Destination-switch rendering boundary* and *Video inspection evidence* in [the 2026-07-18 plan](2026-07-18-settings-palette-and-refresh-preferences-presentation.md). Two repairs failed and are prohibited: `.id(selectedSettingsTab)` on the detail subtree (it made a visible removal/insertion fade), and a disabled-animation route transaction (no change).

## Mechanism

`SettingsNavigationSidebar` writes `AppSettings.selectedSettingsTab`. `SettingsView` re-renders, and `SettingsDetailView` selected the page with a `switch`. Each destination is a different view type, so SwiftUI treats the switch as removing one subtree and inserting another. Every page owns its own `SettingsPage`: a `GeometryReader`, a `ScrollView` backed by an `NSScrollView`, and AppKit-backed pickers, segmented controls and switches. One selection change therefore tore down and rebuilt a native scroll host and its controls in a single transaction. The window size is fixed (`SettingsWindowWidthAnchor` writes it only when the Context Rail toggles), so unlike the menu this is not a window resize.

This is the same class of cause as the two fixed defects:
- **Menu provider switch:** the host window changed height during the switch (fixed by stable geometry, then by the ADR 0004 ordering).
- **Settings Agents tab switch:** the scroll document height changed inside a stable page (fixed by the viewport-filling envelope).

In each case the container that hosts the swapped content changed in the same transaction as the swap. Why General and Notifications show it most is not established; they carry the most AppKit-backed controls, which is a hypothesis, not a finding.

## Change

`SettingsDestinationStack` keeps all six destinations mounted in a `ZStack` with stable per-destination identity. A switch changes only opacity, hit testing, accessibility visibility and focus eligibility (`disabled`); no page or scroll host is removed or inserted. `SettingsDetailView` re-runs, on becoming visible, the refreshes pages used to do in `onAppear`: `launchAtLogin.refresh()` for General, and `refreshClaudePassiveCaptureHealth()` for Agents with Claude selected.

**Overhead.** Settings pages are static forms: none uses a timer, task, `TimelineView` or background work. The only per-appearance work is one `SMAppService` status read and two small file reads. Six mounted pages cost a one-time build when Settings opens and a re-render of the pages observing `QuotaViewModel` on its event-driven publishes; nothing scales per second. No measurable cost is expected on an M1.

**Behavior change.** Each destination keeps its own scroll position while the Settings window is open, instead of returning to the top on every visit.

## Tasks

- [x] Red-first regression: `SettingsDestinationStackTests.testSwitchingDestinationsKeepsEveryPageScrollHost` fails against a `switch`-based stack (the scroll host is replaced) and passes with retained pages.
- [x] Wire `SettingsDestinationStack` into `SettingsDetailView`, with visibility-triggered refreshes.
- [x] `swift build`, `swift test`.
- [x] Signed build delivered without replacing the user's running app.
- [ ] User 60 fps recording: rapid General ↔ Notifications and all six destinations, with the Context Rail hidden and visible, in Light and Dark.
- [ ] VoiceOver and keyboard: hidden pages must not be read or focused.
- [ ] If red: revert and try candidate 2 (one shared scroll host with a viewport-filling envelope), then candidate 3 (AppKit-hosted pages). If green: update `AGENTS.md`'s deferred-defect guidance and the 2026-07-18 plan.

## Verification log

- 2026-09-30: a first test draft used stand-in pages of one view type; SwiftUI reused a single scroll view, so it passed against the `switch` version. That draft was rejected. With distinct page types, matching `SettingsDetailView`, the `switch` version fails (scroll host replaced) and the retained stack passes.
- 2026-09-30: `swift build` and `swift test`: exit 0, 315 tests, 1 skipped (existing glyph test), 0 failures.
- 2026-09-30: `build-app.sh` run from a separate worktree at `9fc4a06` (the ignored asset catalog copied in). "Signed with: Developer ID Application"; `codesign --verify --deep --strict` passed. Delivered as `CodexUsageMonitor/.build/Settings Retained Pages.app`; the user's running Panel Live (PID 34905) and `.build/CodexUsageMonitor.app` were not touched.
