# Compact Settings and Menu Placement Implementation Plan

**Recovered status (2026-07-16): implemented historical work and visually superseded.** The 680 × 520 result, compact 340 × 460 experiment, and 820 × 580 top-tab Figma stage are historical after the strict global-sidebar revision established a 780 × 520 default. The responsive layout and native-menu scrolling/highlight fix remain current. Restored from `wip/figma-followups-2026-07-15` for provenance; do not treat its historical geometry as the current Settings contract.

> **For agentic workers:** This is a historical plan, not an active execution queue. Any current replacement should keep changes surgical, add focused automated coverage for deterministic seams, and use compilation, a signed app build, and direct visual/manual acceptance for native presentation.

**Goal:** Keep Settings responsive, restore its original width with a slightly shorter height, and stop native menu rows from shifting or receiving mismatched highlights beneath the Quit command.

**Architecture:** Extend the shared Settings layout with a container-derived compact mode so labeled rows stack and value-column alignment collapses only when space is constrained. Keep the native `MenuBarExtra` presentation, but prevent its countdown row from changing menu geometry during an open menu-tracking session.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, native `MenuBarExtra`, signed macOS app bundle.

## Global Constraints

- Historical target for this plan: 680 × 520. The current Figma-stage Settings frame is 780 × 520 with one global sidebar and no top `TabView`.
- Use `SettingsPage`, `SettingsSection`, `SettingsLabeledRow`, and `SettingsDescription`; do not add a top-level `Form` or implicit `LabeledContent` column.
- Keep layout metrics centralized in `SettingsLayout.swift`.
- Keep every long page vertically scrollable and retain native controls and system colors.
- Keep the menu in native menu presentation; do not replace it with a window-style popover.
- Historical verification relied on compilation and signed-app acceptance; any current replacement follows the repository's current automated-regression policy.
- Preserve unrelated user changes.

### Task 1: Make the shared Settings layout responsive

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsLayout.swift`
- Modify: Settings pages that currently apply the fixed value-column inset directly

- [x] Add a compact layout mode derived from the `SettingsPage` container width.
- [x] Reduce page margins in compact mode while retaining the existing regular metrics.
- [x] Stack `SettingsLabeledRow` labels above values in compact mode; retain the aligned label/value columns at regular widths.
- [x] Replace direct value-column padding with one shared responsive alignment modifier.
- [x] Constrain compact pickers to the available width and keep descriptions wrapping vertically.

### Task 2: Preserve Agents sidebar navigation

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`

- [x] Keep the fixed 190-point lower sidebar and detail arrangement at the restored width.
- [x] Keep provider navigation below the top Settings tabs.

### Task 3: Stabilize native menu placement and hit testing

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NextRefreshCountdownView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift` only if needed to preserve a stable row identity

- [x] Reproduce from the supplied screenshot and current view hierarchy: menu content updates once per second while native menu tracking is active.
- [x] Keep the countdown useful without publishing per-second SwiftUI layout updates into an open native menu.
- [x] Preserve inline Refresh, Settings, and Quit commands and their ordering.
- [x] Verify pointer movement and scrolling below Quit do not highlight or displace status rows above it. The user confirmed the scrolling/highlight regression is fixed on 2026-07-14.

### Task 4: Build, inspect, and document

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `docs/superpowers/plans/2026-07-13-adaptive-refresh.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/development/operating-notes.md`

- [x] Run `CodexUsageMonitor/Scripts/build-app.sh` and confirm a signed `.app` is produced.
- [x] Retire the 680 × 520 full-tab visual gate in favor of `2026-07-14-figma-settings-port.md`. Its signed 820 × 580 Light pass opened all six tabs; Dark and complete conditional-state coverage remain manual there.
- [x] Inspect the original connected menu state and exercise scrolling/pointer movement below Quit. User-confirmed on 2026-07-14.
- [x] Record observed evidence and any automation/manual limitations in this plan and the affected existing plans.
- [x] Run `git diff --check` and review the final diff for unrelated edits.

## Verification evidence

- `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors` passed after rerunning with compiler-cache access.
- `zsh CodexUsageMonitor/Scripts/build-app.sh` produced and signed `CodexUsageMonitor/.build/CodexUsageMonitor.app`.
- After the final scope correction, the signed 680 × 520/sidebar build passed in 1.47 seconds; strict code-signature verification and `Info.plist` linting also passed.
- A separately identified temporary audit bundle was launched without terminating PID 52398, the pre-existing user-owned instance.
- The superseded compact experiment showed readable Light-mode Notifications and an Agents picker/detail layout. The user then directed restoration of the original width and sidebar, with only the height reduced to 520 points; this final size still requires direct visual acceptance.
- Foreground automation was stopped when active desktop input changed the audit tab and opened the Agents picker between scripted actions. Only audit PID 58317 was terminated; PID 52398 remained running. The user subsequently confirmed Light/Dark Settings behavior and the connected-menu pointer/scroll fix. Remaining full-tab and conditional-state checks stay manual.

## Self-review

- The plan preserves the requested smaller window and native menu presentation.
- The adaptive behavior is owned by shared layout components rather than duplicated page constants.
- The menu change targets dynamic row geometry and does not redesign the popover.
- Verification follows repository policy and does not add automated tests.
