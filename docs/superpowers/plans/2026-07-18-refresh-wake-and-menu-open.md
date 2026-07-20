# Refresh-on-Wake and Fixed Interval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** **Implementation complete — manual regression boundaries remain.** The user confirmed the wake switch is interactive and refreshes on wake, the selectable one-minute option is absent, and the final signed Refresh page has no open row. Refresh on open was briefly explored, then rejected as poor design and removed.

**Goal:** Make **Refresh on wake** a real persisted preference, remove the one-minute fixed interval in favor of a 90-second minimum, and preserve `QuotaMonitor` as the sole owner of refresh execution, coalescing, diagnostics, and scheduling.

**Architecture:** `AppSettings` owns only the Boolean wake preference and normalizes the retired persisted `one-minute` value to `ninety-seconds`. `QuotaMonitor` keeps its one refresh task and one timer and ignores wake notifications when the preference is disabled. The native `MenuBarExtra` remains passive: opening or redrawing it never starts a refresh, timer, polling loop, task, or second scheduler.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit `NSWorkspace.didWakeNotification`, Combine-backed `AppSettings`, existing `QuotaMonitor`, and the signed macOS app build script.

## Scope correction — 2026-07-18

The initial draft considered an event-driven **Refresh on open** preference. The user rejected that interaction as poor design. Its temporary preference, diagnostic reason, view-model forwarding method, menu callback, and documentation were removed before final verification. The Figma v4 reference remains structural design evidence only; it does not authorize an unsupported menu-open refresh behavior.

## Source facts and scope boundary

- `QuotaMonitor.refresh(reason:)` remains the sole in-flight-task, diagnostic, retry, and scheduling boundary.
- The existing wake observer stays registered, but it calls `refresh(reason: .wake)` only when `settings.refreshOnWake` is true.
- `RefreshMode.oneMinute` was stored as `"one-minute"`; initialization now normalizes it to `ninety-seconds` and persists that normalized raw value before the picker is shown.
- The Refresh page uses the shared `SettingsPreferenceToggle` for the working wake preference. It contains no Refresh-on-open control.
- No automated test case is added by user direction. The existing Swift package suite is regression baseline only.
- The report involving `Resets: Jul 25, 2026 at 17:24` is currently non-reproducible and remains a separate native-menu verification item, not a fixed defect.

## Global constraints

- Keep `QuotaMonitor` as the only refresh scheduler, timer owner, retry owner, and coalescing boundary.
- Do not put a timer, `TimelineView`, polling loop, per-second publisher, queue, refresh-on-appear callback, or any refresh request in `MenuBarExtra`.
- Preserve launch, manual, scheduled, authentication, and enabled-wake behavior. Disabled wake suppresses only a wake-triggered collection.
- Default `refreshOnWake` to `true` to preserve existing behavior.
- Migrate persisted `"one-minute"` to `RefreshMode.ninetySeconds` and persist `"ninety-seconds"` before the picker is displayed.
- Do not add test cases. Run the existing package suite as a regression baseline and record signed-app acceptance separately.

## File structure

| File | Responsibility |
| --- | --- |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshSchedule.swift` | Remove one minute; retain 90 seconds as the shortest selectable fixed interval. |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift` | Persist `refreshOnWake` and normalize the legacy one-minute raw value. |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift` | Gate the existing wake event at the monitor boundary. |
| `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift` | Bind the working wake switch and remove unavailable/open copy. |
| `AGENTS.md`, `how-to.md`, `UsageProbe/README.md`, product documentation, and this plan | Preserve the passive-menu boundary, behavior, migration, and verification record. |

## Implementation tasks

### Task 1: Persist wake and retire one minute

- [x] Remove `RefreshMode.oneMinute`, its label, and its 60-second fixed interval while retaining `.ninetySeconds` at 90 seconds.
- [x] Add `AppSettings.refreshOnWake`, persisted at `refresh.onWake`, with a default of `true`.
- [x] Normalize legacy `refresh.mode == "one-minute"` to `.ninetySeconds` and persist the normalized value at initialization.
- [x] Run the existing Swift package suite as regression baseline; no new test case added.

### Task 2: Keep wake execution in the monitor

- [x] Guard the existing `NSWorkspace.didWakeNotification` callback with `settings.refreshOnWake` immediately before `refresh(reason: .wake)`.
- [x] Retain the existing task guard, diagnostics, timer invalidation, and normal next-refresh scheduling.
- [x] Reject and remove all menu-open callback, preference, diagnostic, and view-model routes.

### Task 3: Connect the native Settings control

- [x] Replace the unavailable wake presentation with the shared native `SettingsPreferenceToggle` bound to `$settings.refreshOnWake`.
- [x] Remove the Refresh-on-open row and describe current policy as launch, enabled wake, scheduled, and manual collection.
- [x] Build the signed app and visually confirm the Refresh page shows no Refresh-on-open control, retains a 90-second minimum, and uses the working wake switch.

### Task 4: Record behavior and final acceptance

- [x] Record the reported Reset text exactly as `Resets: Jul 25, 2026 at 17:24` in Product Follow-up 3 and the planning board as non-reproducible verification evidence.
- [x] Update operating documentation: legacy one minute migrates to 90 seconds; wake defaults enabled but is configurable; native menu opening is passive.
- [x] In the signed app, turn wake off and on around a real sleep/wake event and verify the disabled route produces no wake diagnostic. The enabled route was observed; the disabled diagnostic-restraint route remains open.
- [x] Run final package, signed-build, signature, plist, and diff checks. Update this evidence, then commit/push only after approval and generate a filled manual PR draft.

## Acceptance criteria

- Refresh on wake is a persisted native switch, defaults enabled, and suppresses only wake collection when off.
- The Refresh picker has no selectable one-minute option; legacy `one-minute` values normalize to `ninety-seconds`.
- The native menu never becomes a refresh trigger, timer, polling loop, retry loop, second task, or scheduler.
- `QuotaMonitor` retains sole ownership of refresh execution, coalescing, diagnostics, retry, and next-schedule behavior.
- The signed Refresh page has no Refresh-on-open option and preserves native control/layout behavior in Light and Dark.
- The Reset-copy report remains Verification rather than a fixed claim.

## Evidence — 2026-07-18

- **Observed:** The user confirmed the working wake switch refreshed after wake and that the selectable one-minute option was absent. In the final signed app, the user confirmed the Refresh-on-open row was removed and the remaining Refresh UI looked correct.
- **Run:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor` passed after the final wake-only removal: 8 existing tests, 0 failures. No test case was added by user direction.
- **Run:** the signed build completed after the final wake-only removal; strict `codesign` verification accepted the app, `plutil -lint` returned `OK`, and `git diff --check` passed.
- **Not run:** wake-disabled diagnostic restraint; legacy migration in the live signed app; Light/Dark Settings inspection; and the separate long Reset-copy native-menu matrix.
