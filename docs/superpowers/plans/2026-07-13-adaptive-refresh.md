# Adaptive Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` task-by-task. Do not create or run automated tests for this branch; verify with Swift compilation, a signed app build, read-only inspection, and manual UI acceptance.

**Goal:** Replace the fixed five-minute timer with persisted fixed and automatic refresh modes, publish a reliable next-refresh countdown, and make every UI consume one provider-neutral confirmed/completed or cached/paused display contract.

**Architecture:** `AppSettings` owns the persisted user choice. A pure `AdaptiveRefreshPolicy` converts normalized `QuotaRecord` evidence plus recent outcome state into a `RefreshScheduleDecision`; it never calls Codex, reads storage, or mutates UI. Main-actor `QuotaMonitor` remains the single scheduling and display-state owner, uses a one-shot foreground timer, preserves single-flight collection, and publishes shallow state for `QuotaViewModel`. The menu and Settings render that state without deriving freshness from provider strings.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, Foundation, AppKit, macOS 14+; no third-party dependencies and no storage-schema changes.

## Global constraints

- Codex first, but scheduling and display contracts remain provider-neutral.
- Do not create or run automated tests.
- Fixed choices are 1 minute, 1 minute 30 seconds, 2 minutes (default), 5 minutes, and 10 minutes.
- Automatic is the only mode allowed to use 30 seconds. A burst lasts no more than ten minutes and exits when its triggering condition passes or after two consecutive non-live results.
- A trusted live result means `confirmed` or `confirmed-after-retry`. Cached, unconfirmed, and unavailable attempts enter cached/paused mode.
- Cached/paused mode never replaces the last confirmed display record with unconfirmed values. With no confirmed record, show unavailable rather than zero usage.
- Launch and wake always request an immediate refresh. Scheduled work never overlaps an in-flight manual, launch, or wake refresh.
- These short foreground intervals use a one-shot `Timer`; `NSBackgroundActivityScheduler` is intentionally excluded because macOS treats it as deferrable work suited to intervals of roughly ten minutes or more.
- Update `outline.md`, `how-to.md`, `UsageProbe/README.md`, the roadmap, and this plan whenever behavior changes.

---

### Task 1: Persist the refresh mode and define the schedule decision contract

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshSchedule.swift`

**Interfaces:**
- Produces `RefreshMode`, `RefreshScheduleDecision`, `RefreshScheduleReason`, and `AdaptiveRefreshPolicy.decision(...)`.
- Consumes only `QuotaRecord`, consecutive failure count, current date, and burst start date.

- [x] **Step 1: Add the persisted mode with a two-minute migration default**

Define `RefreshMode: String, Codable, CaseIterable, Identifiable, Sendable` with `.automatic`, `.oneMinute`, `.ninetySeconds`, `.twoMinutes`, `.fiveMinutes`, and `.tenMinutes`. Fixed cases return 60/90/120/300/600 seconds; automatic returns no fixed interval. Persist `AppSettings.refreshMode.rawValue` under `refresh.mode`, falling back to `.twoMinutes` for absent or invalid values.

- [x] **Step 2: Add a provider-neutral decision value**

```swift
struct RefreshScheduleDecision: Equatable, Sendable {
    let interval: TimeInterval
    let reason: RefreshScheduleReason
    let isAutomaticBurst: Bool
    let isBurstConditionActive: Bool
}
```

Give each reason concise user-facing copy for Settings: fixed choice, normal automatic pace, fast consumption, low remaining quota, imminent threshold, qualified exhaustion, reset verification, and failure backoff.

- [x] **Step 3: Implement deterministic automatic policy ordering**

Evaluate in this order:

1. two or more consecutive non-live results -> 300 seconds;
2. an active/new eligible burst -> 30 seconds, bounded to ten minutes;
3. one non-live result -> 300 seconds;
4. remaining <= 10%, medium/high qualified exhaustion, or reset within 30 minutes -> 60 seconds;
5. remaining <= 25% or confirmed rate >= 5% per hour -> 90 seconds;
6. remaining <= 50% or confirmed rate >= 1% per hour -> 120 seconds;
7. otherwise -> 300 seconds.

A burst is eligible when a positive confirmed rate predicts crossing the next lower 50/25/10/5 threshold within ten minutes, a medium/high forecast predicts exhaustion at least 15 minutes before reset and within ten minutes, or a reset is due within ten minutes/has just become overdue. Once the current value has crossed a threshold, target the next lower threshold so the completed event does not hold the burst open.

- [x] **Step 4: Compile the scheduling-domain slice**

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor`. Expected: `Build complete!`; do not run tests.

---

### Task 2: Generalize monitoring presentation into two explicit display states

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitoringState.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`

**Interfaces:**
- Produces `QuotaDisplayMode`, `QuotaPauseReason`, and `QuotaDisplayState`.
- `QuotaMonitor.displayState` is the sole freshness/display transition source for current and future UI.

- [x] **Step 1: Define the provider-neutral display contract**

Add the roadmap contract with `confirmedCompleted` and `cachedPaused`, an optional displayed record, last attempt, optional last confirmation, and normalized pause reason. Include display labels in the domain type so views do not reinterpret provider confirmation values.

- [x] **Step 2: Centralize outcome transitions in `QuotaMonitor`**

On confirmed/confirmed-after-retry, publish the new record as confirmed/completed and reset the failure count. On cached-last-known-good, preserve its historical collection time as `lastConfirmedAt`, publish it only as cached/paused, and count the attempt as non-live. On unconfirmed/unavailable, keep the in-memory last confirmed record; if none exists, publish nil. Always update `lastAttemptAt` at completion and normalize the pause reason.

- [x] **Step 3: Keep notification evaluation on the latest attempt**

Continue passing the latest `QuotaRecord` to `QuotaNotifier`; never pass a display-substituted record as a fresh attempt. This preserves failure/stale notification behavior while preventing unconfirmed UI values.

- [x] **Step 4: Compile the display-state slice**

Run the signed app build. Inspect the public monitor publishers and confirm no view needs `source`, raw `detail`, or cache-file access to determine freshness.

---

### Task 3: Replace the repeating timer with a one-shot adaptive scheduler

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`

**Interfaces:**
- Publishes `nextRefreshAt`, `effectiveRefreshInterval`, and `refreshScheduleReason`.
- Observes `AppSettings.$refreshMode` and reschedules without starting overlapping collection.

- [x] **Step 1: Schedule only after each completed attempt**

Remove the repeating 300-second timer. After a refresh finishes, ask the policy for a decision, update the published schedule state, and create one non-repeating main-run-loop timer. When it fires, clear the timer and request `.scheduled`; after that attempt finishes, calculate the next decision again.

- [x] **Step 2: Preserve single-flight and lifecycle triggers**

Keep `refreshTask == nil` as the collection gate. A scheduled fire during an active collection is discarded and the completion path schedules from the new evidence. Launch and wake invalidate the pending timer and immediately request refresh. Cancellation clears the stored task without publishing an incomplete attempt.

- [x] **Step 3: Track automatic burst lifetime in the monitor**

Store only `automaticBurstStartedAt` and consecutive non-live attempt count. Clear burst state when the trigger disappears, the mode becomes fixed, ten minutes elapse, or two non-live attempts occur. Do not persist transient scheduler state across launches.

- [x] **Step 4: Reschedule when the user changes mode**

Subscribe once to `settings.$refreshMode.removeDuplicates().dropFirst()`. Invalidate the pending timer, clear burst state, and schedule the new mode from now without forcing a collection. Fixed choices must always publish their exact selected interval.

- [x] **Step 5: Compile and inspect timer ownership**

Run the signed build, then use `rg` to confirm only one monitor-owned refresh timer remains and that it is non-repeating. Do not run the app automatically.

---

### Task 4: Make the view model a shallow adapter for display and scheduling state

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsStatus.swift`

- [x] **Step 1: Mirror the monitor publishers**

Publish `displayState`, `nextRefreshAt`, `effectiveRefreshInterval`, and `refreshScheduleReason`. Derive menu presentation and forecasts only from `displayState.displayedRecord`, using the existing unavailable presentation when nil.

- [x] **Step 2: Update Settings status without leaking provider details**

Build `SettingsStatus` from `QuotaDisplayState` so Agents, Diagnostics, and Refresh agree on confirmed/cached status and timestamps. Keep raw failure text outside this status object.

- [x] **Step 3: Compile the adapter slice**

Run a signed build and inspect that views remain free of monitor/repository initialization and persistence reads.

---

### Task 5: Add working refresh controls and the live menu countdown

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NextRefreshCountdownView.swift`

- [x] **Step 1: Replace planned copy with a real refresh-mode picker**

Bind a Picker to `viewModel.settings.refreshMode`. Show Automatic, 1 minute, 1 minute 30 seconds, 2 minutes, 5 minutes, and 10 minutes. Below it show the effective interval/reason and next scheduled time; explain that only Automatic temporarily reaches 30 seconds.

- [x] **Step 2: Render the two-state status in the native menu**

Replace the verification row with `Confirmed / completed` or `Cached / paused`. In paused mode show the normalized reason, last successful refresh when available, and last attempt. Keep quota values from the last confirmed record visibly labeled as cached. Preserve inline native menu commands and `.menuBarExtraStyle` behavior.

- [x] **Step 3: Show a live next-refresh countdown beside refresh timing**

Use a small AppKit-backed read-only label whose coordinator updates the displayed string directly while the native menu remains open. Do not drive a native-menu countdown through `TimelineView`, timer-interval `Text`, or other periodic SwiftUI invalidation. Render `Last refresh: <time> · Next: <countdown>` when scheduled, `Refreshing…` during collection, and `Scheduling…` only before the first decision. The countdown must stop at zero rather than showing a negative duration.

- [ ] **Step 4: Perform manual UI acceptance**

Build and open the signed app only with user approval. Verify Settings mode changes reschedule immediately; fixed choices display exact intervals; the menu countdown advances while open; refresh commands remain inline; cached/paused copy does not claim cached data is current.

---

### Task 6: Document and close the branch

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/superpowers/plans/2026-07-13-adaptive-refresh.md`

- [x] **Step 1: Document the controls and state language**

Record every fixed choice, the two-minute default, Automatic’s bounded 30-second behavior, countdown meanings, launch/wake behavior, and confirmed/completed versus cached/paused semantics.

- [x] **Step 2: Record branch dependency and Figma sequencing**

State that `feature/adaptive-refresh` is stacked on `feature/settings-foundation` until that branch reaches main. Keep `feature/figma-ui-overhaul` explicitly frontend-only and scheduled after stable functional branches.

- [x] **Step 3: Run final verification**

Run `git diff --check`, a fresh signed app build, and read-only `rg` checks for the timer and UI state contract. Do not run tests. Record exact verification evidence here before committing or pushing.

## Verification evidence (2026-07-13)

- `git diff --check`: passed with no output.
- Final signed bundle build: `Build complete! (0.18s)` and ad-hoc signing completed for `CodexUsageMonitor/.build/CodexUsageMonitor.app`.
- Timer inspection: one monitor-owned `Timer(timeInterval:repeats: false)` registered in the main run loop's common mode; no repeating refresh timer remains.
- UI state inspection: menu and Settings consume `QuotaDisplayState`; neither derives freshness from `QuotaPresentation.confirmation`.
- App launch: the freshly signed bundle opened successfully.
- Automated Settings/menu inspection was blocked because macOS denied `osascript` keystrokes without Accessibility permission. Task 5 Step 4 remains a user-visible manual checkpoint; no automated tests were created or run.

## Countdown rendering correction (2026-07-13)

Manual observation found that the original `TimelineView(.periodic)` displayed the correct deadline but did not receive periodic invalidations while the native menu was tracking, so its text changed only after a refresh rebuilt the menu. Replacing it with timer-interval `Text` made the countdown tick, but refresh transitions then crashed in SwiftUI menu rendering.

The macOS diagnostic reports at 16:03:28 and 16:03:46 show `EXC_BAD_ACCESS` after unbounded repetition of `MenuBehavior.menuNeedsUpdate`, `ViewRendererHost.render`, and `AttributeGraph.propagate_dirty` on the main thread. This is a stack overflow caused by periodic SwiftUI menu invalidation, not a quota collection or scheduling failure. `NextRefreshCountdownView` now uses an `NSViewRepresentable` coordinator with a main-run-loop timer that changes only `NSTextField.stringValue`; the one-second tick no longer publishes state or dirties the SwiftUI menu graph. The user-visible refresh/crash and open-menu ticking behavior remain the manual acceptance checks.

Verification: the replacement compiled and the final signed app bundle built successfully (`Build complete! (0.13s)`). The coordinator invalidates its timer when the row is dismantled, while refreshing, or when the deadline has elapsed. A read-only process check also confirmed that the corrected app remained alive after its launch refresh.
