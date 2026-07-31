# Quota History Foundation Implementation Plan

> **For agentic workers:** Use the executing-plans workflow inline, task by task. The user explicitly requested functional changes only; do not change the menu UI or generate test cases.

**Goal:** Make confirmed Codex quota data durable and future-UI-ready by exposing it through one repository and retaining a bounded, sanitized history with deterministic exhaustion forecasts.

**Architecture:** `QuotaRepository` is the only quota-refresh module known to application state. It owns the existing read-only Codex collector, records only trusted snapshots in `QuotaHistoryStore`, and returns a `QuotaRecord` containing the current presentation plus history-derived forecasts. The existing SwiftUI quota rows consume those forecasts without learning collection or storage details.

**Tech Stack:** Swift 6.2, Foundation, existing `CodexUsageMonitor` Swift package; no dependencies.

## Global Constraints

- Do not modify `CodexUsageMonitorApp.swift`; keep forecast rendering within the existing quota rows.
- Do not send prompts, spend reset credits, read `auth.json`, or add an OAuth implementation.
- Persist only a one-way account fingerprint and normalized confirmed quota fields; never persist email, token, prompt, or raw RPC data.
- Append history only for `confirmed` and `confirmed-after-retry` results.
- Scope history by provider, account fingerprint, limit lane, and reset timestamp; never calculate a forecast across different reset windows.
- Retain at most 500 entries and remove entries older than 90 days.
- Do not generate or run test cases. Validate through compilation and live read-only app-server output.
- Update `docs/development/operating-notes.md`, `UsageProbe/README.md`, and the Codex MVP plan when behavior/storage changes.

---

### Task 1: Define persisted observation and forecast domain

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaHistory.swift`

**Interfaces:**

```swift
struct QuotaHistoryEntry: Codable, Equatable, Sendable {
    let providerID: String
    let accountFingerprint: String
    let limitID: String
    let collectedAt: Date
    let fiveHour: QuotaWindow
    let weekly: QuotaWindow
}

struct QuotaForecast: Codable, Equatable, Sendable {
    let projectedExhaustionAt: Date?
    let resetAt: Date
    let percentPerHour: Double
}

struct QuotaRecord: Sendable {
    let presentation: QuotaPresentation
    let fiveHourForecast: QuotaForecast?
    let weeklyForecast: QuotaForecast?
}
```

- [x] Add the types above with an internal `QuotaHistoryEntry.init?(presentation:)` that refuses an untrusted presentation or a missing identity/lane/window/reset time.
- [x] Add `QuotaForecast.calculate`, using only entries with the same reset timestamp (within two minutes), at least two chronological observations, and a positive usage slope. It returns `nil` if projected exhaustion occurs at or after the reset time.

### Task 2: Add bounded owner-only history persistence

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaHistoryStore.swift`

**Interfaces:**

```swift
final class QuotaHistoryStore {
    func entries(matching presentation: QuotaPresentation) -> [QuotaHistoryEntry]
    func append(_ entry: QuotaHistoryEntry)
}
```

- [x] Store a versioned JSON document at `~/Library/Application Support/CodexUsageMonitor/quota-history.json`.
- [x] Treat malformed or missing history as empty; do not make quota collection fail because history is unavailable.
- [x] Dedupe entries with the same provider, fingerprint, lane, collection time, and reset times.
- [x] Prune entries older than 90 days, then keep the most recent 500; write atomically and set directory/file permissions to `0700`/`0600`.

### Task 3: Deepen the refresh seam with `QuotaRepository`

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaRepository.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**

```swift
actor QuotaRepository {
    func refresh() async -> QuotaRecord
}
```

- [x] Let the repository own `CodexQuotaCollector` and `QuotaHistoryStore`.
- [x] Keep the collector’s confirmation/cache policy unchanged.
- [x] Persist only a new trusted history entry; derive the two forecasts from entries matching the current identity and reset window.
- [x] Change `QuotaViewModel` to depend on `QuotaRepository`, assign `record.presentation` exactly as it assigned the collector result, and continue notifying with that same presentation.
- [x] Pass repository forecasts through `QuotaViewModel` and render a compact projected-exhaustion line in the existing matching quota row only when a forecast is valid.

### Task 4: Verify and document the invisible functional foundation

**Files:**
- Modify: `docs/development/operating-notes.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/superpowers/plans/2026-07-12-codex-menu-bar-mvp.md`

- [x] Compile the Swift package with Xcode 26.3.
- [x] Run `./.build/debug/CodexUsageMonitor --live-read-once` and confirm a trusted snapshot returns without a prompt or reset-credit action.
- [x] Inspect only file presence, mode, and JSON field names for `quota-history.json`; its file mode is `0600` and its schema excludes tokens, email, prompts, and raw RPC data.
- [x] Document the new local history path, 90-day/500-entry retention, privacy boundary, and forecast display conditions.

## Self-review

- Scope coverage: the plan adds only collection-adjacent data capabilities; no menu source is modified.
- Future-UI leverage: a new UI can call one `QuotaRepository.refresh()` interface and later consume `QuotaRecord` forecasts without learning Codex app-server or persistence details.
- Safety: provider data remains read-only and all durable data excludes secrets and raw account identity.
- Validation: only compiler and live read-only verification are used, per user direction.

## Superseded details

The foundation was implemented and verified before the reliability-hardening phase. The later `2026-07-13-codex-reliability-hardening.md` plan now owns the evolved forecast contract: forecasts require three observations over at least 15 minutes, use median adjacent positive slopes, and include confidence and observation count. Current operating documentation in `docs/development/operating-notes.md` and `UsageProbe/README.md` reflects the stricter behavior.
