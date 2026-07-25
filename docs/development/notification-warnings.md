# Notification warnings — what they are and how they fire

**Scope.** This documents the **"Other Warnings"** section on the Notifications
settings page ([`NotificationSettingsView.swift`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/NotificationSettingsView.swift))
— the five non-quota alert toggles — plus the global mechanics they share. The
per-agent *remaining-quota* threshold chips (50/25/10/5%) are a separate control
covered by Workstream E of the [prototype-finalization plan](../superpowers/plans/2026-07-24-prototype-finalization.md);
they are summarized here only where they interact.

**Verified 2026-07-25** by tracing each toggle from the UI binding to a real,
produced notification event. All five are wired and functional. Delivery itself
is signed-app behavior (see *Delivery gate* below) and is not exercised by
`swift test`.

## The five toggles

Each toggle is a persisted `@Published` boolean on
[`AppSettings`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift),
defaults to **on**, and gates a specific class of notification in
[`QuotaNotifier`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift).

| UI label | Setting | Defaults key |
|---|---|---|
| Forecasted exhaustion | `forecastWarningsEnabled` | `notification.forecastWarnings` |
| Reset-credit expiration | `resetCreditWarningsEnabled` | `notification.resetCreditWarnings` |
| Quota reset or reset failure | `resetWarningsEnabled` | `notification.resetWarnings` |
| Stale quota data | `staleDataWarningsEnabled` | `notification.staleDataWarnings` |
| Extended update interruptions | `refreshFailureWarningsEnabled` | `notification.refreshFailureWarnings` |

## Delivery path (shared by all five)

```
QuotaMonitor.refresh()                       // Codex read cycle completes
  └─ notifier.evaluate(record, interruptionState, transition)   // QuotaMonitor.swift:165
       ├─ guard settings.alertsEnabled                          // master toggle
       ├─ NotificationPolicy.evaluate(...) → [NotificationEvent] // reset / stale / interruption
       │     └─ for event where isEnabled(event) → deliver      // per-toggle gate
       ├─ resetCreditWarningsEnabled → credit-expiry events     // in QuotaNotifier.evaluate
       └─ forecastWarningsEnabled   → forecast events           // in QuotaNotifier.evaluate
```

- **[`NotificationPolicy`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift)**
  is the pure, testable state machine that turns two consecutive *confirmed*
  quota reads (plus the refresh-interruption state) into `NotificationEvent`s
  carrying a stable `key`, `title`, and `body`.
- **[`QuotaNotifier`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift)**
  applies the per-toggle gate, dedups, and posts to `UNUserNotificationCenter`.
  It also owns the two event families that are *not* in the policy
  (forecast and reset-credit), because those read forecast/credit fields
  directly off the record rather than diffing two snapshots.

The per-toggle gate is split by **event-key prefix** in
[`QuotaNotifier.isEnabled`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L128):
`reset-` → `resetWarningsEnabled`, `stale-data-` → `staleDataWarningsEnabled`,
`refresh-interruption-` → `refreshFailureWarningsEnabled`. Forecast
(`forecast-…`) and reset-credit (`credit-…`) events are gated by an explicit
`guard`/`if` in `evaluate` before they are ever produced, so their prefixes are
intentionally *not* listed in `isEnabled`.

## What triggers each warning

### 1. Forecasted exhaustion — `forecastWarningsEnabled`
- **Gate:** [`QuotaNotifier.swift:72`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L72).
- **Trigger:** on a **confirmed** read, for each of the 5-hour and weekly lanes,
  `forecastAlert` fires when the record carries a forecast of **medium or high**
  confidence whose projected exhaustion is at least **15 minutes before** the
  window's reset ([`QuotaNotifier.swift:78`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L78)).
- **Notification:** *"Codex usage may exhaust before reset"* — key
  `forecast-codex-<limitID>-<lane>-<resetTime>-<15minBucket>`. The 15-minute
  bucket means a moved projection can re-alert once per bucket, but a stable
  projection alerts once.

### 2. Reset-credit expiration — `resetCreditWarningsEnabled`
- **Gate:** [`QuotaNotifier.swift:65`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L65).
- **Trigger:** for every date in `presentation.resetCreditExpiryDates`, fires a
  **24-hour** warning when the credit expires within a day and a **1-hour**
  warning when it expires within an hour.
- **Notification:** *"Codex reset credit expires soon"* — keys
  `credit-<expiry>-24h` and `credit-<expiry>-1h`.
- This is Codex-specific (earned reset credits are a Codex plan concept).

### 3. Quota reset or reset failure — `resetWarningsEnabled`
- **Gate:** [`QuotaNotifier.swift:129`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L129) (`reset-` prefix).
- **Trigger:** produced by [`NotificationPolicy.resetEvent`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift#L58)
  by comparing the previous confirmed read to the current one, per lane:
  - **reset completed** — the reset timestamp moved forward (>120s) *and*
    remaining % went up → *"Codex &lt;lane&gt; quota reset"* (key `reset-complete-…`).
  - **reset failed** — the scheduled reset time has passed but **two** confirmed
    reads still report the old window → *"Codex &lt;lane&gt; quota did not reset"*
    (key `reset-failed-…`). The two-observation requirement suppresses a
    single-read false alarm.

### 4. Stale quota data — `staleDataWarningsEnabled`
- **Gate:** [`QuotaNotifier.swift:130`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L130) (`stale-data-` prefix).
- **Trigger:** in [`NotificationPolicy`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift#L38),
  when the app is **not** in a refresh-interruption state and the newest trusted
  snapshot is **≥15 minutes old**.
- **Notification:** *"Codex quota data is stale"* — key
  `stale-data-<collectedAt>-<15minBucket>`, so it re-alerts once per additional
  15 minutes of staleness while it persists.
- The interruption guard prevents this from double-firing alongside warning #5.

### 5. Extended update interruptions — `refreshFailureWarningsEnabled`
- **Gate:** [`QuotaNotifier.swift:131`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L131) (`refresh-interruption-` prefix).
- **Trigger:** in [`NotificationPolicy`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/NotificationPolicy.swift#L30),
  when `interruptionState` is `.backedOff` — the refresh scheduler enters this
  after **three unsuccessful refreshes**, then retries every 10 minutes. This is
  exactly the behavior the section's helper text describes.
- **Notification:** *"Codex usage updates are paused"* — key
  `refresh-interruption-<episodeID>`. The key is per-episode, so one alert per
  interruption episode; a new disconnection is a new episode and re-alerts.

## Global mechanics

- **Master toggle.** All five are subordinate to **"Enable quota notifications"**
  (`alertsEnabled`). The UI applies `.disabled(!alertsEnabled)` to the whole
  section, and `QuotaNotifier.evaluate` early-returns when it is off
  ([`QuotaNotifier.swift:52`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L52)).
  `alertsEnabled` also drives the macOS authorization request flow
  ([`setAlertsEnabled`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L21)).
- **Fire-once dedup.** Every warning is delivered through
  [`deliverOnce`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift#L139),
  which records the event key in `UserDefaults` and refuses to re-post it. The
  keys embed the varying dimension (reset time, staleness bucket, episode id) so
  a genuinely new occurrence gets a new key and can alert again.
- **Delivery gate (`.app` only).** `QuotaMonitor` constructs a `QuotaNotifier`
  **only** when running inside a real `.app` bundle
  ([`QuotaMonitor.swift:41`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift#L41));
  otherwise the notifier is `nil` and nothing is posted. So CLI runs and
  `swift test` never touch Notification Center — these five warnings are
  validated by unit-testing the pure policy/gate logic, not by asserting a real
  banner.
- **Persistence & defaults.** Each toggle persists to its
  `notification.*` `UserDefaults` key and **defaults to on**
  ([`AppSettings.swift:90-94`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AppSettings.swift#L90));
  `alertsEnabled` itself defaults to off until the user enables it.

## Provider scope (important)

The five "Other Warnings" currently produce **Codex-only** events — every title
is hard-coded `"Codex …"` and every source (`NotificationPolicy`, forecasts,
reset credits) is fed by the Codex read cycle in `QuotaMonitor`. Claude's
notifier ([`QuotaViewModel.deliverClaudeThresholdAlerts`](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift#L297))
delivers **only** the per-agent remaining-quota threshold alerts and the
settings-change confirmation; it does not emit forecast, reset, stale, or
interruption warnings. The toggles are presented globally (per Workstream E's
"Other Warnings stay global" decision), but their *delivery* is Codex-scoped
today. Extending any of these to Claude would mean giving `ClaudeUsageMonitor`
an equivalent event source and namespacing the titles/keys per provider — a
future enhancement, not a current gap.

## Test coverage

- [`NotificationPolicyTests`](../../CodexUsageMonitor/Tests/CodexUsageMonitorTests/NotificationPolicyTests.swift)
  covers the interruption-event path.
- Reset/stale/forecast/credit logic lives in the pure `NotificationPolicy` and
  `QuotaNotifier` gate (`isEnabled` prefix routing), which are unit-testable
  without Notification Center. Real banner delivery remains signed-app
  acceptance under the branch's GUI waiver.
