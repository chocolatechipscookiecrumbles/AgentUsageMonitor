# Settings System Appearance Transition Implementation Plan

> **For agentic workers:** Use `executing-plans` to implement this plan task by task. Keep unchecked acceptance items open until they are directly observed.

**Status (2026-07-16):** The reported Light → System/System-Dark regression is fixed. Signed-app acceptance now covers both macOS Light and Dark hosts, live OS appearance changes, the reciprocal native-menu boundary, and all six destinations in explicit Light. Manufactured conditional states remain manual.

**Goal:** Make the live Settings window transition completely between System, Light, and Dark without mixed AppKit/SwiftUI regions, reopening the window, resetting session state, or changing native menu appearance.

**Verified architecture:** `AppSettings` remains the persisted choice owner. `SettingsView` is the only presentation owner and always supplies a concrete `preferredColorScheme`. Explicit Light/Dark map directly; System maps to a live observation of `NSApplication.effectiveAppearance`. System therefore remains a persisted semantic choice while its presentation continues following later macOS changes. The preference is scoped to the Settings presentation, and the native `MenuBarExtra` remains system-controlled.

**Why this differs from the original plan:** A bridge inside the SwiftUI Settings scene could not reliably own its containing `NSWindow`. Signed-app tracing showed the scene cleared the window override after the bridge applied it while a private presentation host retained the stale explicit appearance. Clearing the window did not clear that host, which recreated the mixed window. A delayed bridge write made explicit Light mixed and was also rejected. The accepted implementation does not mutate `NSWindow.appearance` or `NSApplication.appearance`.

**Tech stack:** Swift 6.2, SwiftUI, AppKit KVO, Combine-backed `AppSettings`, XCTest, macOS 14+, and signed-app visual acceptance at the default 780 × 548 window frame observed by Accessibility.

## Global constraints

- Preserve **System**, **Light**, and **Dark**, with System as the default and the `general.appearance` persistence key unchanged.
- Keep one presentation owner. Do not combine an AppKit window bridge with SwiftUI `preferredColorScheme`.
- Never transition the Settings presentation from an explicit color scheme to `nil`; that is the stale-host failure boundary reproduced in the signed Settings scene.
- System is not a one-time snapshot. Observe the application's effective appearance and update the open Settings presentation whenever it changes.
- Read `NSApplication.effectiveAppearance`, but do not assign `NSApplication.appearance`; native menu presentation must remain system-controlled.
- Preserve destination, search text, page scroll, Context Rail state, keyboard focus, window identity, controls, and semantic colors.
- Do not use `.id(...)`, window recreation, delayed competing writes, or individual background/color patches to hide propagation failures.
- Build and inspect the signed `.app`; compilation and isolated hosting harnesses are supporting evidence only.

---

## Task 1: Preserve the diagnosis and acceptance boundary

### Evidence

- [x] A minimal host reproduced that changing a live SwiftUI presentation from `.preferredColorScheme(.light)` to `nil` can leave its subtree Light under a Dark host.
- [x] The failure reproduced without `AppSettings`, persistence, Figma surfaces, or the three-column layout, ruling those out as root causes.
- [x] A plain `NSWindow` harness showed that clearing `window.appearance` inherits the host correctly, but the signed SwiftUI `Settings` scene falsified that harness as a complete model of the app.
- [x] An isolated signed process reproduced the original failure with the first bridge implementation.
- [x] Temporary signed-app tracing recorded this sequence:
  - the bridge applied Aqua to the Settings window;
  - the SwiftUI Settings scene later cleared the window to inherited Dark;
  - a private presentation host remained Aqua;
  - choosing System left the window and root hosting view Dark while that presentation host remained Aqua.
- [x] Deferring the bridge write was tested separately and rejected because explicit Light itself became mixed.

### Acceptance matrix

| Transition or lifecycle event | Settings presentation | Native menu |
| --- | --- | --- |
| Light → System while macOS is Dark | Existing window and all regions become Dark together. | Remains Dark/system-controlled. |
| Dark → System while macOS is Light | Existing window and all regions become Light together. | Remains Light/system-controlled. |
| System → Light → System under macOS Dark | Dark → Light → Dark without resetting session state. | Remains Dark. |
| System → Dark → System under macOS Light | Light → Dark → Light without resetting session state. | Remains Light. |
| macOS appearance changes while System is selected | Open Settings follows the new effective appearance. | Follows macOS independently. |
| Reopen/relaunch with explicit Light or Dark | Persisted explicit choice is presented uniformly. | Continues following macOS. |
| Reopen/relaunch with System | Persisted choice remains System and resolves from the current host. | Follows macOS. |

---

## Task 2: Implement a live Settings presentation owner

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppearancePreference.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SystemAppearanceObserver.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/SettingsAppearancePresentationTests.swift`

- [x] Write focused tests before implementation for System resolving to the current host scheme, explicit choices ignoring the host scheme, and a live observer responding to host changes.
- [x] Run the focused test red. Compilation failed because `presentationColorScheme(system:)` and `SystemAppearanceObserver` did not exist.
- [x] Map `AppearancePreference.system` to the observer's current `ColorScheme`; map explicit Light/Dark directly.
- [x] Observe `NSApplication.effectiveAppearance` through KVO and publish only the derived Light/Dark scheme on the main actor.
- [x] Attach the concrete scheme once at the `SettingsView` presentation boundary without changing the HStack identity.
- [x] Remove the failed `SettingsWindowAppearanceBridge` implementation and its now-misleading window-only tests.
- [x] Run the focused tests green: 3 tests, 0 failures.
- [x] Run the full suite with `-Xswiftc -warnings-as-errors`: 5 tests, 0 failures and no compiler warnings.

---

## Task 3: Perform signed-app visual acceptance

### Isolated audit setup

- [x] Confirm no pre-existing `CodexUsageMonitor` process is running.
- [x] Build the signed bundle with `bash CodexUsageMonitor/Scripts/build-app.sh`.
- [x] Launch and track an audit-owned executable process, confirm its Settings window through Accessibility, and close only that process after restoring System.

### Directly observed on 2026-07-16 under macOS Dark

- [x] Reproduce the original Light → System transition in the same open signed Settings window. After a two-second settle, title bar, Navigation Sidebar, page, cards, controls, dividers, and Context Rail were uniformly Dark.
- [x] Exercise System → Light → System without recreating Settings.
- [x] Preserve the selected General destination, a non-empty search query, a scrolled page, hidden Context Rail, and text-field focus through that round trip. The query still filtered the sidebar after the transition, confirming it was not reset.
- [x] Open all six destinations in System Dark with the Context Rail hidden and again with it visible. No mixed fills, stale dividers, clipped leading labels, trailing overflow, or inaccessible bottom content was observed in the captured default-size window.
- [x] Force Settings Light and open the native menu. Settings stayed Light while the menu stayed Dark/system-controlled.
- [x] Verify explicit Light survives Settings close/reopen.
- [x] Restore System, relaunch the app, and verify the picker still says System and Settings resolves Dark from the current host.
- [x] Restore System before closing each audit process; confirm no monitor process remains.

### User-observed on 2026-07-16 under macOS Light and live OS switching

- [x] Under macOS Light, inspect Dark → System and System → Dark → System in the same live Settings window.
- [x] Change macOS Light ↔ Dark through the normal System Settings control while Settings remains open and System is selected; confirm Settings follows each change and restore the original OS preference.
- [x] Under macOS Light, force Settings Dark and confirm the native menu remains Light/system-controlled.
- [x] Repeat the all-six-destination pass in explicit Light on the final build.

### Remaining manual acceptance

- [ ] Exercise manufactured conditional states: disabled notification controls, missing permission/connection guidance, absent quota values, and long status strings.

This remaining unchecked row limits conditional-state coverage but does not block review of the scoped appearance-transition fix.

---

## Task 4: Reconcile documentation and final verification

**Files:**

- Modify: `AGENTS.md`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`
- Modify: `docs/superpowers/plans/2026-07-14-figma-settings-global-sidebar.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`

- [x] Replace the obsolete window-bridge guidance and known-regression text with the verified presentation-owner model.
- [x] Keep the System-Light and manufactured-state acceptance gaps explicit in developer-facing plans.
- [x] Run `git diff --check`, the focused tests, the warning-clean full suite, the signed-app build, and strict signature verification.
- [x] Review the final diff for unrelated changes and prepare an evidence-rich PR handoff.

### Final verification evidence

- **Run:** `swift test --filter SettingsAppearancePresentationTests` — 3 tests passed, 0 failures.
- **Run:** `swift test -Xswiftc -warnings-as-errors` — 5 tests passed, 0 failures, no compiler warnings.
- **Run:** `bash CodexUsageMonitor/Scripts/build-app.sh` — signed app rebuilt successfully after the final concurrency refinement.
- **Run:** `codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app` — valid on disk and satisfies its designated requirement.
- **Run:** `plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist` — OK.
- **Run:** `git diff --check` — no whitespace errors.
- **Observed:** the final rebuilt signed app repeated Light → System under macOS Dark in the same 780 × 548 window and remained uniformly Dark after a two-second settle.
- **Observed:** System was restored and the audit-owned process was closed; `pgrep -fl CodexUsageMonitor` returned no process.
- **Observed by user:** Dark → System and System → Dark → System passed under macOS Light in the same live Settings window.
- **Observed by user:** the open System-selected Settings window followed live macOS Light ↔ Dark changes, and the original OS appearance was restored.
- **Observed by user:** with macOS Light and Settings forced Dark, the native menu remained Light/system-controlled.
- **Observed by user:** all six destinations passed in explicit Light on the final signed build.

## Self-review

- The implementation fixes the stale presentation owner rather than recoloring surfaces.
- `NSApplication.appearance` is never mutated, and the native menu boundary is directly verified under System Dark.
- No `.id`, Settings recreation, or delayed timing workaround is used.
- Automated coverage verifies mapping and live observation; signed-app evidence verifies the original failure path and the full Settings hierarchy.
- The appearance transition matrix is accepted across macOS Light and Dark; manufactured conditional states remain explicitly unchecked rather than inferred.
