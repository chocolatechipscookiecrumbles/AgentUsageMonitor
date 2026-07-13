# Codex Reliability Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task by task. The user has asked for no generated test cases; verify with compilation, read-only live refreshes, and a one-week observation log.

**Goal:** Make the existing Codex monitor reliably collect, explain, and forecast quota data for one week before adding providers or redesigning the UI.

**Architecture:** Preserve `QuotaRepository.refresh() -> QuotaRecord` as the deep external interface for quota data. Move refresh cadence, retry/backoff, and sanitized diagnostic recording behind a monitoring module so the present menu and a later UI overhaul consume the same state rather than managing provider processes themselves. Keep the Codex adapter experimental and retain its three-sample confirmation and last-known-good policy.

**Tech Stack:** Swift 6.2, Foundation, AppKit/SwiftUI lifecycle notifications, UserNotifications, existing local JSON persistence; no network service or third-party dependency.

## Current-plan review

### What is complete and demonstrated

- The native macOS menu-bar app builds with Xcode 26.3 and reads Codex through the read-only app-server sequence.
- Three-sample confirmation rejects the observed transient near-empty provider response and falls back to account-matched last-known-good data.
- The app persists owner-only confirmed history, calculates same-reset forecasts, and displays a forecast only when its current rules permit one.
- Build products, live probe output, credentials, and quota caches are excluded from Git.

### Risks that should block provider expansion

1. **Experimental provider contract:** `account/rateLimits/read` is useful but not documented as a stable personal quota interface. One week of confirmation/fallback evidence is required before treating the Codex path as dependable enough to copy.
2. **Refresh semantics:** the current five-minute timer checks `NSApp.isActive`. A menu-bar-only app may be inactive while its process is intentionally running, so scheduled refreshes may be skipped unexpectedly.
3. **Forecast confidence:** two nearby observations can imply an unrealistic consumption rate. The displayed forecast currently has no confidence/freshness rule beyond matching reset windows.
4. **No diagnostic history:** the app stores confirmed quota history but not sanitized refresh outcomes, so recurring transient snapshots, timeouts, and cache fallback rates cannot be measured objectively.
5. **Personal-development packaging:** `Scripts/build-app.sh` produces a local unsigned bundle. Launch at login, Developer ID signing/notarization, updates, widgets, CloudKit, and Watch targets remain out of scope.

### Deliberate deferrals

- GitHub Copilot: requires a separately proven official allowance path and a user-authorized identity/credential strategy.
- Claude: start with local analytics only; do not promise quota retrieval until independently validated.
- UI overhaul: defer until the monitoring state and forecast confidence interface have survived the hardening period.
- Widgets, CloudKit, iPhone, Watch, signing, and automatic updates: defer until the single-provider snapshot is stable.

## Global constraints

- Do not send model prompts, consume reset credits, read `auth.json`, or create a custom OAuth flow.
- Retain only sanitized data: provider/lane identifiers, one-way account fingerprint, normalized windows, timestamps, confirmation state, and classified failures.
- Never write raw app-server messages, email addresses, tokens, prompt text, or local Codex database contents to diagnostic storage.
- Do not make a manual refresh wait behind a background refresh; allow only one collection at a time.
- Do not redesign the menu in this phase. Add visible diagnostic detail only if a real failure requires an explanation.
- Do not generate or run test cases. Use the verification steps stated in each task.
- Update `how-to.md`, `UsageProbe/README.md`, and this plan whenever behavior or persistence changes.

---

### Task 1: Create a provider-neutral monitoring state module

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitoringState.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interface:**

```swift
@MainActor
final class QuotaMonitor: ObservableObject {
    @Published private(set) var record: QuotaRecord
    @Published private(set) var refreshState: RefreshState

    func start()
    func refresh(reason: RefreshReason)
}
```

- [x] Make `QuotaMonitor` own `QuotaRepository`, one in-flight refresh task, AppKit wake observation, and the five-minute timer.
- [x] Define `RefreshReason` as `.launch`, `.scheduled`, `.wake`, and `.manual`; define `RefreshState` as `.idle`, `.refreshing(reason:)`, and `.failed(at:)`.
- [x] Replace the `NSApp.isActive` timer guard with an explicit “monitor process is running” policy. Continue collecting only while the app has not been quit; never collect after the monitor is deallocated.
- [x] Keep collection serialized: a scheduled or wake refresh while one is in flight must be ignored; a manual request during a refresh must be visibly disabled by the existing view model binding.
- [x] Reduce `QuotaViewModel` to a UI adapter that mirrors `QuotaMonitor.record.presentation`, forecasts, and refresh state. Do not change `QuotaMenuView` layout in this task.
- [ ] Verify: build the bundle, launch it, wait over five minutes without opening the menu, then open it and confirm `Last refresh` advanced.

### Task 2: Persist privacy-safe refresh diagnostics

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshDiagnosticsStore.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaPresentation.swift`

**Interface:**

```swift
enum RefreshOutcome: String, Codable, Sendable {
    case confirmed
    case confirmedAfterRetry = "confirmed-after-retry"
    case cachedLastKnownGood = "cached-last-known-good"
    case unconfirmed
    case unavailable
}

struct RefreshDiagnostic: Codable, Sendable {
    let startedAt: Date
    let completedAt: Date
    let reason: RefreshReason
    let outcome: RefreshOutcome
    let failureKind: String?
}
```

- [x] Classify failures into stable non-secret kinds such as `codex-not-found`, `not-authenticated`, `timeout`, `invalid-response`, and `inconsistent-samples`; do not persist provider error text.
- [x] Append one diagnostic record after every completed refresh, retain 30 days and 1,000 entries, and use the same `0700`/`0600` Application Support permissions.
- [x] Record confirmation/cache state even when there is no failure, so fallback frequency can be measured.
- [x] Add an internal `diagnosticSummary()` that returns counts by outcome and failure kind for a time range; do not add a menu screen yet.
- [ ] Verify: force no failure modes. Confirm normal launches and manual refreshes append only classified, sanitized diagnostics by inspecting JSON field names and permissions, not values.

### Task 3: Make forecasts conservative and explainable

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaHistory.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaRepository.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`

**Interface:**

```swift
enum ForecastConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

struct QuotaForecast: Codable, Equatable, Sendable {
    let projectedExhaustionAt: Date
    let resetAt: Date
    let percentPerHour: Double
    let confidence: ForecastConfidence
    let observationCount: Int
}
```

- [x] Require at least three confirmed observations spanning at least 15 minutes inside the same reset window before returning a forecast.
- [x] Use a robust rate (median adjacent positive usage slopes) rather than only the oldest and newest values; return no forecast when values do not show a stable positive trend.
- [x] Assign confidence from observation count and span: low for 3–4 observations/under one hour, medium for at least five observations/at least one hour, high for at least eight observations/at least three hours.
- [x] Continue suppressing any projection at or after the reset time.
- [x] In the existing forecast line, append a compact confidence label only after the forecast is valid, such as `Projected exhaustion: 3:40 PM · medium confidence`.
- [ ] Verify after enough real refreshes: compare the label with history length/span and confirm a reset-window change removes the old forecast.

### Task 4: Add forecast-aware alerts without broadening notification scope

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Notifications/QuotaNotifier.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`

**Interface:**

```swift
func evaluate(_ record: QuotaRecord) async
```

- [x] Keep current threshold and reset-credit alerts unchanged.
- [x] Emit one forecast alert only for a medium/high-confidence forecast that projects exhaustion at least 15 minutes before its reset.
- [x] Deduplicate forecast alerts by provider, lane, reset timestamp, and projected-exhaustion bucket rounded to 15 minutes.
- [x] Never alert from cached, unconfirmed, unavailable, or low-confidence data.
- [ ] Verify by inspecting the decision path with a real qualified forecast; do not manufacture or consume quota to trigger an alert.

### Task 5: Run and review the one-week hardening period

**Files:**
- Modify: `UsageProbe/Findings/codex.md`
- Modify: `docs/superpowers/plans/2026-07-12-codex-menu-bar-mvp.md`
- Modify: `how-to.md`

- [ ] Run the installed menu-bar app for seven calendar days under normal work.
- [ ] At the end, summarize confirmed, confirmed-after-retry, cached, unconfirmed, and unavailable counts; do not export account-specific quota values.
- [ ] Record whether the foreground-independent scheduled cadence worked, whether any refresh overlapped, and whether a forecast materially disagreed with later observed exhaustion/reset behavior.
- [ ] Decide from evidence whether the Codex adapter remains experimental, can be promoted for personal use, or needs its confirmation thresholds revised.
- [ ] Only after this review, choose one independent next plan: GitHub Copilot capability research, Claude local-analytics research, or a UI overhaul. Do not start two provider integrations together.

### Task 6: Publish a provider-neutral two-state UI contract

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitoringState.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`

**Interface:** Use `QuotaDisplayState`, `QuotaDisplayMode`, and `QuotaPauseReason` exactly as defined in `2026-07-13-codex-daily-driver-roadmap.md`. Monitoring owns the state transition; UI surfaces only render it.

- [ ] Publish **confirmed/completed** only when the latest refresh returns `confirmed` or `confirmed-after-retry` live data.
- [ ] Publish **cached/paused** when the latest refresh is cached-last-known-good, unconfirmed, unavailable, or paused after repeated failures.
- [ ] Preserve the last confirmed `QuotaRecord` for display during cached/paused mode; never replace it with an unconfirmed snapshot or zero-value placeholder.
- [ ] Track `lastAttemptAt` separately from `lastConfirmedAt` so every UI can explain when collection last ran and how old the displayed trusted data is.
- [ ] Render the mode, timestamps, and normalized pause reason in the menu popover without making the view inspect provider-specific errors or `ConfirmationState`.
- [ ] Verify with read-only live refreshes: one successful result renders confirmed/completed, while a naturally occurring failed/unconfirmed refresh renders cached/paused and retains the prior confirmed record.

## Decision gates after this plan

| Evidence | Next step |
| --- | --- |
| ≥95% confirmed/confirmed-after-retry and no harmful stale replacement | Begin GitHub Copilot capability research as a separate Phase 0 plan. |
| Repeated cache fallback, unconfirmed reads, or unstable resets | Refine Codex validation before adding a provider. |
| Forecasts have sufficient history but prove materially inaccurate | Improve forecast model and confidence rules; do not add forecast alerts. |
| Refresh cadence is stable and data interface unchanged | Begin a separate UI-overhaul design, consuming `QuotaRecord`/monitoring state only. |

## Self-review

- This plan keeps the current deep data seam (`QuotaRepository`) and adds a monitoring module rather than spreading lifecycle logic into future UI code.
- It introduces no provider credentials, remote services, CloudKit, widgets, or UI redesign.
- It supplies measurable evidence for the one-week gate the MVP plan already required.
