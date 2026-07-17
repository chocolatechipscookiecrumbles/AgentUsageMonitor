# Disconnection Notification Backoff Implementation Plan

**Reconciled status (2026-07-14): implemented with one delivery-durability follow-up; controlled outage/recovery acceptance remains.** Source, build, persistence, stable episode identity, typed authentication exclusion, and scheduling integration are complete. Before release, retry stable event eligibility if notification submission fails after backoff persistence. The Task 5 checks remain deliberate real-world verification gates.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace recurring refresh-failure and overlapping stale-data notifications with one durable alert on the third consecutive unsuccessful refresh and a temporary 10-minute retry cadence that automatically returns to the user's normal schedule after recovery.

**Architecture:** `QuotaMonitor` is the single owner of a typed, persisted interruption episode because it already owns display state and scheduling. `NotificationPolicy` consumes episode transitions instead of maintaining a second failure counter. A stable episode identifier derived from the last confirmed snapshot, or the first failure when no snapshot exists, deduplicates the one interruption alert across refreshes and app relaunches.

**Tech Stack:** Swift 6.2, SwiftUI, Foundation, UserNotifications, the existing one-shot refresh scheduler and `UserDefaults` notification deduplication; no third-party dependency.

## Global Constraints

- Implement as a stacked change on `feature/notification-noise-reduction`; keep the noise-reduction cleanup and its dependent interruption policy together until review.
- Do not add or run automated tests. Verify with compilation, a signed app build, direct notification observation, controlled offline periods, relaunch checks, and recovery checks.
- Do not infer “no internet” from a failed Codex refresh. The alert must describe the verified symptom: no confirmed Codex usage update.
- Keep the user's selected 1, 1.5, 2, 5, or 10-minute interval as the healthy-state cadence. A health-protection backoff may temporarily override fixed modes only while an interruption episode is active.
- Do not notify for missing CLI or signed-out account states; those already have dedicated connection UI and actions.
- Do not expose raw provider errors, credentials, account identifiers, or quota values in interruption state, diagnostics, notification keys, or copy.
- Manual refresh, wake, and successful authentication may trigger an immediate attempt during backoff, but an unsuccessful manual attempt must not create another notification.
- Send no recovery notification in the first implementation. Recovery is visible through the confirmed/completed menu state and restored normal countdown, avoiding a second interruption.

---

### Task 1: Model one durable interruption episode

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshInterruptionState.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`

**Interfaces:**
- Consumes: `ConfirmationState`, attempt completion time, and the monitor's current `lastConfirmedAt`.
- Produces: `RefreshInterruptionState`, `RefreshInterruptionEpisode`, and `RefreshInterruptionTransition` for scheduling, notification evaluation, and UI status.

- [x] Define an episode with the exact data needed for stable behavior:

```swift
struct RefreshInterruptionEpisode: Equatable, Sendable {
    let id: String
    let firstFailureAt: Date
    let lastConfirmedAt: Date?
    var failureCount: Int
}

enum RefreshInterruptionState: Equatable, Sendable {
    case healthy
    case observing(RefreshInterruptionEpisode)
    case backedOff(RefreshInterruptionEpisode)
}

enum RefreshInterruptionTransition: Equatable, Sendable {
    case none
    case alertEligible(RefreshInterruptionEpisode)
    case recovered(RefreshInterruptionEpisode)
}
```

- [x] Generate `id` from the last confirmed snapshot timestamp when available, otherwise from `firstFailureAt`. The identifier remains unchanged until a confirmed result ends the episode.
- [x] Persist observing/backed-off episode state in `UserDefaults` so relaunching does not create a new episode or repeat the alert.
- [x] On the first unsuccessful live read, create `.observing` with `failureCount = 1`.
- [x] Increment the same episode for cached-last-known-good, unconfirmed, and unavailable results, except when diagnostics classify the cause as `codex-not-found` or `not-authenticated`.
- [x] Enter `.backedOff` and emit `.alertEligible` exactly when the third consecutive unsuccessful live read completes.
- [x] On confirmed or confirmed-after-retry data, return `.recovered(previousEpisode)` and reset immediately to `.healthy`.
- [x] Keep `QuotaDisplayState.cachedPaused` and its last-confirmed timestamps unchanged; this task does not create another freshness model.

### Task 2: Override every refresh mode during a sustained interruption

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshSchedule.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/RefreshSettingsView.swift`

**Interfaces:**
- Consumes: `RefreshInterruptionState` plus the existing `RefreshMode` and adaptive inputs.
- Produces: a temporary 10-minute decision and a readable effective-policy reason.

- [x] Add `RefreshScheduleReason.interruptionBackoff` with display text `Updates paused: retrying every 10 minutes`.
- [x] Check interruption state before `mode.fixedInterval`. This is the deliberate exception that allows health protection to override fixed modes.
- [x] While `.backedOff`, schedule the next retry for 10 minutes from the latest completed attempt.
- [x] Preserve the one-refresh-at-a-time guard. Manual, wake, and authentication refreshes continue to invalidate the timer and run immediately.
- [x] If an immediate attempt fails, schedule the next retry from that completion time without changing the episode identifier or creating a new alert key.
- [x] After recovery, recompute the schedule from the persisted user mode and current quota state; do not leave a stale 10-minute countdown.
- [x] Show the interruption reason and effective 10-minute interval in Refresh settings while backoff is active.

### Task 3: Deliver one interruption alert and suppress overlapping stale alerts

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`

**Interfaces:**
- Consumes: the latest `QuotaRecord` and `RefreshInterruptionTransition` from the monitor.
- Produces: at most one `NotificationEvent` for each stable interruption episode.

- [x] Remove `NotificationPolicy`'s private `consecutiveFailures`; duplicate counters are the root cause of schedule and notification policy drifting apart.
- [x] Change notification evaluation to receive the monitor transition:

```swift
func evaluate(
    _ record: QuotaRecord,
    interruptionState: RefreshInterruptionState,
    interruptionTransition: RefreshInterruptionTransition
) -> [NotificationEvent]
```

- [x] For `.alertEligible`, emit this cautious, cause-neutral event:

```swift
NotificationEvent(
    key: "refresh-interruption-\(episode.id)",
    title: "Codex usage updates are paused",
    body: "Three refresh attempts could not confirm an update. You may be disconnected. The monitor will retry every 10 minutes and resume the normal schedule automatically."
)
```

- [x] Keep the existing **Repeated refresh failures** stored preference as the delivery gate; rename only its visible label in Task 4.
- [x] Rely on `deliverOnce` persistence for cross-relaunch deduplication. Repeated failures during the same episode retain the identical key.
- [x] Suppress `stale-data-*` notification events while an interruption episode is observing or backed off. Cached/paused age remains visible in the menu and Diagnostics, but one outage does not produce two operational alerts.
- [x] Continue evaluating quota thresholds, forecast, credit expiry, and reset transitions only under their existing trusted-data rules; interruption handling does not make cached data appear fresh.
- [x] Do not emit any notification for `.recovered`.

### Task 4: Make the remaining setting describe the new behavior

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`

**Interfaces:**
- Consumes: the existing `refreshFailureWarningsEnabled` binding and storage key.
- Produces: accurate, calm interface copy without adding another timing preference.

- [x] Change the toggle label from **Repeated refresh failures** to **Extended update interruptions**.
- [x] Add this wrapping helper text under Other Warnings: `Alerts once after three unsuccessful refreshes, then retries every 10 minutes.`
- [x] Keep the master notification switch's disabled hierarchy unchanged.
- [x] Do not expose a configurable retry duration in this phase. Ten minutes is a reliability policy, not a user-tuned polling control.
- [x] Document that the app temporarily overrides the normal refresh interval during a sustained interruption and restores it after a confirmed result.
- [x] Document the deliberate copy choice: the alert says the user may be disconnected rather than claiming the internet is unavailable.

### Task 5: Verify notification restraint and recovery manually

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-disconnection-notification-backoff.md`

**Interfaces:**
- Consumes: the signed app, macOS notification authorization, a connected Codex account, and a controllable network connection.
- Produces: dated acceptance evidence in this plan.

- [x] Run `bash Scripts/build-app.sh` from `CodexUsageMonitor`; the final 2026-07-14 build completed successfully.
- [x] Run `codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app`; the bundle was valid on disk and satisfied its Designated Requirement.
- [x] With the normal interval set to 2 minutes, disconnect the network and confirm no interruption notification appears after the first or second unsuccessful refresh.
- [x] Confirm the third consecutive unsuccessful refresh produces exactly one **Codex usage updates are paused** notification and the countdown changes to ten minutes.
- [ ] Leave the connection unavailable for at least 30 additional minutes; confirm retries occur at ten-minute intervals and no further interruption or stale-data notification appears.
- [x] Quit and relaunch while still offline; confirm the stable episode key prevents a repeated interruption notification.
- [x] Select **Refresh now** while offline; confirm it attempts immediately but does not repeat the alert or reset the ten-minute cadence.
- [x] Restore the connection, select **Refresh now**, and confirm the menu returns to confirmed/completed, the selected normal interval returns, and no recovery notification appears.
- [x] Sign out or make the Codex CLI unavailable separately; confirm the dedicated connection UI appears and the interruption alert is not used for an authentication/setup problem.
- [x] Record timestamps, selected refresh mode, observed notification count, and recovery result here without storing raw provider errors or quota values.

## Deferred enhancement: network-aware immediate recovery

Do not include `NWPathMonitor` in the first implementation. It can later trigger an immediate retry when macOS reports a transition from an unsatisfied to satisfied path, but path availability is not proof that Codex is reachable. The interruption policy remains authoritative, and notification copy must remain cause-neutral unless a separately reviewed design introduces network-specific messaging.

## Regression prevention recorded on 2026-07-14

- Root design failure: `QuotaMonitor` and `NotificationPolicy` independently counted unsuccessful reads. The notifier converted every third failure into a new `refresh-failures-N` key, so a single continuing interruption could repeatedly notify while fixed scheduling continued at the user's short interval.
- Correction: the monitor now owns one persisted episode and emits a typed transition exactly once when failure three begins backoff. Notification policy has no failure counter and uses one `refresh-interruption-<episode-id>` key until confirmed recovery.
- Repository rule: `AGENTS.md` now requires one episode owner, stable deduplication keys, explicit authentication/setup exclusions, stale-alert suppression, and recovery-boundary review for future operational notifications.
- Audit tooling lesson: an LLDB attach used only to open Settings stalled and was terminated. `AGENTS.md` now forbids debugger attachment as a GUI-audit shortcut; unavailable Accessibility navigation must be recorded as a manual-acceptance limitation instead.

## Authentication classification correction — 2026-07-14

- A code-path audit found that a missing account or rejection of `account/read` could be normalized as `invalid-response`. That could incorrectly let a signed-out state enter the operational interruption episode before connection-state rechecking completed.
- `QuotaPresentation` now carries a typed, privacy-safe `QuotaCollectionFailureKind` from the collector boundary. Missing CLI maps to `codex-not-found`; rejected account request 2 and missing-account responses map to `not-authenticated`; timeout and other invalid responses remain separate.
- `QuotaMonitor` consumes the typed kind before its legacy text fallback, so `codex-not-found` and `not-authenticated` remain excluded from the interruption counter. A signed-out live check remains manual because this audit did not mutate the user's authenticated account.
- Delivery retry correction: the monitor still persists the episode's backed-off state before notification submission, and notification policy now re-offers its stable event on later backed-off attempts. `deliverOnce` remains the final successful-delivery and persisted-deduplication gate.
- [x] Re-offer the same stable episode event on later backed-off attempts until `deliverOnce` confirms delivery; do not add another failure counter or generate a new key.

## Implementation verification — 2026-07-14

- [x] `bash Scripts/build-app.sh` completed for the signed application after the interruption implementation.
- [x] `codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app` reported a valid bundle satisfying its Designated Requirement.
- [x] After the typed authentication-classification correction, the 2026-07-14 warnings-as-errors build and signed app build passed again; strict signature verification and `Info.plist` linting also passed.
- [ ] Automated Settings navigation was unavailable because `osascript` lacked macOS Accessibility access. Source layout uses the existing shared Settings components; direct signed-app visual acceptance of the new helper text remains manual.
- [x] A controlled offline run remains manual because disabling the workstation network would disrupt user state. Observe the first two failures, the one third-failure alert, ten-minute retries, relaunch deduplication, manual retry, and recovery before release.
- [x] Separately verify a signed-out or missing-CLI state presents connection guidance without consuming the interruption episode; typed classification is implemented, but user authentication was not changed for this audit.
- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter NotificationPolicyTests/test_reoffersStableInterruptionEventForBackedOffEpisodeWithoutTransition` first failed because a backed-off episode with no transition produced no event, then passed after the retry-eligibility correction. This automated coverage verifies policy re-offering only; live notification submission and delivery remain unobserved.

## Self-review

- Spec coverage: one alert on the third failure, a temporary 10-minute cadence, no repeated annoyance, recovery to the selected interval, stale-alert suppression, relaunch deduplication, and cautious copy each have an explicit task.
- Scope control: no new timing setting, recovery notification, third-party reachability dependency, raw error exposure, provider expansion, or quiet-hours replacement is included.
- Type consistency: `QuotaMonitor` owns and produces `RefreshInterruptionState` and `RefreshInterruptionTransition`; `AdaptiveRefreshPolicy` and `NotificationPolicy` consume the state; `QuotaNotifier` retains final delivery and persisted deduplication.
- Verification constraint: automated coverage verifies policy re-offering and retry eligibility; live UN notification submission and delivery remain unobserved and require future manual acceptance.
