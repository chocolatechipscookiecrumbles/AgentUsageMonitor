# Dynamic Menu Bar Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted General preference that switches the macOS menu-bar label between the existing gauge and a live `5H: x% | Week: x%` display, with Remaining and Used value modes.

**Architecture:** `AppSettings` owns the two persisted presentation choices. A pure `MenuBarLabelPresentation` derives visible and accessible strings from the existing provider-neutral `QuotaDisplayState`; it never collects quota itself. `MenuBarStatusLabel` observes both `QuotaViewModel` and `AppSettings`, so preference changes render immediately and quota values render after every launch, wake, authentication, manual, or scheduled refresh already managed by `QuotaMonitor`.

**Tech Stack:** Swift 6.2, SwiftUI, Combine-backed `ObservableObject`, Foundation `UserDefaults`, macOS 14 `MenuBarExtra`; no third-party dependencies.

## Global Constraints

- Implement on `feature/menu-bar-display`, stacked on commit `84c8baf` from `feature/codex-connection`.
- Do not add or run automated tests. Verify with compilation, signed-app launch, persisted preference checks, manual refresh, and scheduled-refresh observation.
- Keep the initial appearance choices to **Gauge** and **5-hour and weekly**.
- Keep the value choices to **Remaining** and **Used**, defaulting to **Remaining**.
- Render the dual appearance exactly as `5H: 64% | Week: 82%`, substituting the current values.
- Display `—` for an unavailable lane; never invent `0%`.
- In Used mode, calculate `100 - remaining`, clamped to `0...100`.
- In cached/paused mode, retain the last confirmed values and show a visible pause marker plus an accessible freshness description.
- Use the existing refresh policy as the only quota-update clock. Fixed modes update after refreshes scheduled at 60, 90, 120, 300, or 600 seconds; Automatic may schedule from 30 through 600 seconds. Do not add a second collection timer.
- Update the label immediately after an accepted refresh completes, after a manual refresh completes, and whenever Appearance or Show changes.
- Update `docs/superpowers/plans/2026-07-13-menu-bar-display.md`, the daily-driver roadmap, `outline.md`, `docs/development/operating-notes.md`, and `UsageProbe/README.md` with implemented behavior and verification evidence.

---

### Task 1: Persist the menu-bar presentation choices

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/MenuBarDisplayStyle.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/QuotaValueMode.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`

**Interfaces:**
- Produces: `MenuBarDisplayStyle.gaugeAndLowest`, `MenuBarDisplayStyle.fiveHourAndWeekly`, `QuotaValueMode.remaining`, `QuotaValueMode.used`, `AppSettings.menuBarDisplayStyle`, and `AppSettings.quotaValueMode`.
- Consumes: `UserDefaults` keys `menuBar.displayStyle` and `menuBar.valueMode`.

- [x] Define each enum in its own file with `String`, `CaseIterable`, `Identifiable`, and `Sendable` conformance plus user-facing `title` values.
- [x] Add both keys and `@Published` settings properties to `AppSettings`, persisting raw values in each `didSet`.
- [x] Default missing or invalid display-style values to `.gaugeAndLowest` and missing or invalid value-mode values to `.remaining`.
- [x] Preserve every existing notification and refresh setting key and default.

### Task 2: Derive stable visual and accessibility content

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState`, `MenuBarDisplayStyle`, and `QuotaValueMode`.
- Produces: `text`, `showsGauge`, `showsPauseMarker`, and `accessibilityLabel` for `MenuBarStatusLabel` and the General preview.

- [x] Read quota windows only from `displayState.displayedRecord?.presentation`, ensuring cached/paused mode cannot replace the last confirmed values with failed-refresh data.
- [x] For `.gaugeAndLowest`, show the minimum available remaining value in Remaining mode and the maximum available used value in Used mode, keeping the gauge focused on the most-consumed lane.
- [x] For `.fiveHourAndWeekly`, format both lanes as `5H: <value> | Week: <value>` in stable order with whole percentages and an em dash for each missing lane.
- [x] Mark `.cachedPaused` with `showsPauseMarker == true`, including the initial no-record state.
- [x] Produce VoiceOver text that names both lanes, the selected value mode, and whether values are confirmed or cached; do not read the visual pipe separator.

### Task 3: Make the MenuBarExtra label reactive

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Consumes: `QuotaViewModel.displayState`, `AppSettings.menuBarDisplayStyle`, `AppSettings.quotaValueMode`, and `MenuBarLabelPresentation`.
- Produces: the live `MenuBarExtra` label and a reusable preview view.

- [x] Render gauge imagery only for `.gaugeAndLowest`, render the dual format without the gauge, use monospaced digits, and show a small `pause.fill` marker in cached/paused mode.
- [x] Combine the visible elements into one accessibility element using `MenuBarLabelPresentation.accessibilityLabel`.
- [x] Make `MenuBarStatusLabel` observe both `QuotaViewModel` and its `AppSettings` instance so changes from either source invalidate the label.
- [x] Change the app-owned view model wrapper from `@State` to `@StateObject` and replace the inline `Label` with `MenuBarStatusLabel`.
- [x] Remove the legacy `QuotaViewModel.menuBarTitle` string now that `MenuBarLabelPresentation` owns this formatting.
- [x] Confirm the display uses the existing `QuotaMonitor` refresh emission and does not create a timer, task loop, collector, or repository.

### Task 4: Add General controls and live preview

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `AppSettings` bindings, `QuotaDisplayState`, and `MenuBarLabelPresentation`.
- Produces: General **Menu Bar** section with **Appearance**, **Show**, **Preview**, and refresh-cadence guidance.

- [x] Pass the shared `AppSettings` and current `QuotaDisplayState` into `GeneralSettingsView` without creating another settings instance.
- [x] Add an **Appearance** picker with **Gauge** and **5-hour and weekly** choices.
- [x] Add a **Show** picker with **Remaining** and **Used** choices; use a two-choice picker rather than a Boolean switch with an implicit off meaning.
- [x] Render a live **Preview** using the same `MenuBarLabelPresentation` and `MenuBarLabelView` as the real menu-bar label.
- [x] Add the description “Updates after each quota refresh using the frequency selected in Refresh.”

### Task 5: Document and manually verify the dynamic display

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-menu-bar-display.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `docs/development/operating-notes.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: final branch behavior and verification evidence.
- Produces: current operating instructions and an accurate roadmap status.

- [x] Run `swift build --package-path CodexUsageMonitor` and require a clean exit.
- [x] Run `zsh CodexUsageMonitor/Scripts/build-app.sh` from the repository root and require an ad-hoc signed `.app` bundle.
- [ ] Launch the signed app, switch both Appearance choices and both Show choices, and verify the label and preview update without reopening the app.
- [ ] Trigger **Refresh now** and verify the label changes in the same refresh completion cycle when the returned values differ.
- [ ] Select a fixed refresh mode, observe one scheduled refresh within that mode's documented interval, and verify the label remains synchronized with the popover values.
- [ ] Relaunch and confirm both preferences persist.
- [x] Record completed verification and any remaining visual checks in all five documentation files.

## Implementation and verification notes

- `swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors` passed after the implementation with Swift 6.2.
- `zsh CodexUsageMonitor/Scripts/build-app.sh` produced an ad-hoc signed bundle; `codesign --verify --deep --strict` and `plutil -lint` passed.
- A new signed instance launched at 18:32:41 CST, remained alive through its launch refresh, and produced no crash report newer than the pre-existing 16:03:46 report. The temporary instance was then closed without touching the user's older running instance.
- The implementation adds no timer, task loop, collector, repository, or concurrency boundary. `MenuBarStatusLabel` observes the existing main-actor view model and settings objects.
- Still manual: visually switch both Appearance and Show values, confirm persistence after relaunch, trigger a value-changing manual refresh, and observe one complete scheduled-refresh interval.

## Self-review

- Spec coverage: the plan includes the requested dual-lane label, Used/Remaining choice, immediate preference changes, and refresh-bound dynamic updates.
- Timing ownership: `QuotaMonitor` remains the sole quota scheduler and collector; menu presentation only observes published state.
- Data trust: `QuotaDisplayState.displayedRecord` preserves last-confirmed data during cached/paused results, and unavailable lanes remain explicit.
- Accessibility: visual abbreviations and separators have a full semantic alternative, and cached status is not communicated by color alone.
- Scope control: notification thresholds, General appearance, launch at login, hotkeys, Agents layout, Dashboard, other providers, and additional compact menu styles remain outside this branch.
- Verification constraint: no automated test files or test commands are added; build, signed launch, relaunch, manual refresh, and one scheduled refresh provide acceptance evidence.
