# Codex Dashboard Implementation Plan

> **Recovered status (2026-07-16): Deferred at the user's direction.** Restored from `wip/figma-followups-2026-07-15` with its partial historical checklist intact. Do not resume it without explicit user direction and a revalidation of its interfaces against current `main`, repository `AGENTS.md`, and the evidence-rich PR guidance.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one separate, focusable macOS Dashboard window that turns confirmed Codex quota history and privacy-safe refresh diagnostics into current status, reset-separated charts, consumption metrics, forecasts, changes, outcome rates, data age, and inferred reset history.

**Architecture:** A read-only `DashboardAnalyticsService` actor owns disk reads and converts existing sanitized stores into provider-neutral value models; Dashboard views never read files, account fingerprints, provider errors, or Codex services. `DashboardViewModel` publishes one immutable snapshot for the selected range, and `DashboardView` renders that snapshot alongside the shared `QuotaDisplayState` so confirmed/completed, cached/paused, and unavailable states keep the same meaning as the menu and Settings.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Charts, Foundation, Combine, existing JSON history/diagnostic stores; no third-party dependencies.

## Global Constraints

- Implement on `feature/dashboard` from the locally merged `main` branch.
- Add focused automated coverage for deterministic analytics and state seams; verify native window/chart presentation separately with compilation, signed-app inspection, read-only store inspection, and manual state/range/window acceptance.
- Keep one combined Dashboard window; do not split metrics into separate windows.
- Range choices are 24 hours, 7 days (default), 30 days, and 90 days.
- Never draw a continuous chart line across different reset-window timestamps.
- Never display or return account fingerprints, limit identifiers, email, credentials, prompts, source code, raw provider responses, raw provider errors, or credit/reset-credit details.
- Credits and earned reset-credit information remain in the menu popover.
- Treat missing evidence as unavailable with an explanation; never substitute zero usage, zero change, zero rate, or zero resets.
- Consume `QuotaDisplayState` directly. Cached/paused content must show the last-confirmed timestamp and must not look current.
- Keep the current bare native SwiftUI theme. Visual work in this branch is functional layout only; the planned Figma branch remains separate.
- Every user-visible behavior change updates this plan, `outline.md`, `how-to.md`, `UsageProbe/README.md`, and the daily-driver roadmap.

---

### Task 1: Expose bounded read-only analytics inputs

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/QuotaHistoryStore.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshDiagnosticsStore.swift`

**Interfaces:**
- Consumes: the existing owner-only `quota-history.json` and `refresh-diagnostics.json` schemas.
- Produces: `QuotaHistoryStore.entries(matching:from:through:) -> [QuotaHistoryEntry]` and `RefreshDiagnosticsStore.entries(from:through:) -> [RefreshDiagnostic]`.

- [x] Add a range-bounded history overload that requires the current normalized presentation for account/limit matching, calls the existing private loader, and returns entries sorted by `collectedAt`.
- [x] Add a range-bounded diagnostics reader that calls the existing private loader and returns entries sorted by `completedAt`.
- [x] Keep file URLs and decoder details private; no view or view model may receive a store URL or unfiltered history.
- [ ] Build the package and confirm the existing collection and Settings call sites still compile without modification.

### Task 2: Define dashboard ranges and privacy-safe output models

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardRange.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardMetricValue.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardChartPoint.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardLaneSnapshot.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardOutcomeSnapshot.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardSnapshot.swift`

**Interfaces:**
- Consumes: `QuotaWindowKind`, `QuotaWindow`, `QuotaForecast`, `QuotaDisplayMode`, and normalized refresh outcomes.
- Produces: immutable `Sendable` values used by the analytics actor and SwiftUI views.

- [ ] Define `DashboardRange` cases `day`, `week`, `month`, and `quarter` with display names `24 hours`, `7 days`, `30 days`, and `90 days`, plus durations of 1, 7, 30, and 90 days. Use `.week` as the view-model default.
- [ ] Define `DashboardMetricValue<Value: Equatable & Sendable>` as `.available(Value)` or `.unavailable(String)` so views cannot confuse absent evidence with numeric zero.
- [ ] Define `DashboardChartPoint` with `id`, `lane`, `resetWindowID`, `collectedAt`, `usedPercent`, and `remainingPercent`. Derive `resetWindowID` only from the normalized reset timestamp and never from account data.
- [ ] Define `DashboardLaneSnapshot` with current used/remaining values, reset time, consumption rate, sustainable rate, forecast time/confidence/observation count, 15-minute/1-hour/24-hour change values, reset-separated chart points, inferred reset count, and latest inferred reset time.
- [ ] Define `DashboardOutcomeSnapshot` with total attempts, confirmed count/rate, cached count/rate, and unavailable-or-unconfirmed count/rate. Rates remain unavailable when total attempts is zero.
- [ ] Define `DashboardSnapshot` with selected range, generated time, display mode, last attempt, last confirmed, data age, five-hour lane, weekly lane, and outcome snapshot. Do not include account fingerprint, plan ID, credit fields, or raw diagnostics.

### Task 3: Build the read-only analytics service

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardAnalyticsService.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState`, `DashboardRange`, `QuotaHistoryStore`, `RefreshDiagnosticsStore`, and an explicit `now` date.
- Produces: `func snapshot(displayState: QuotaDisplayState, range: DashboardRange, now: Date = .now) -> DashboardSnapshot` on an actor-isolated service.

- [ ] Return unavailable lane and outcome metrics when no confirmed display record exists; do not query account history without the normalized current presentation needed for filtering.
- [ ] Read only entries between `now - range.duration` and `now`, and pass the current presentation into the history store so another account or limit cannot enter the snapshot.
- [ ] Group chart points by lane and normalized reset timestamp. Preserve the group identifier on every point so `LineMark` series never bridges reset windows.
- [ ] Calculate lane consumption rate from the existing forecast when available. Calculate sustainable rate as `remainingPercent / hoursUntilReset` only when the reset is in the future and the remaining duration is positive.
- [ ] Calculate 15-minute, 1-hour, and 24-hour used-percentage changes against the latest observation at or before each cutoff. Return an unavailable explanation if the selected range or retained history has no baseline.
- [ ] Infer a reset only when consecutive confirmed history entries change to a later reset timestamp and the later used percentage is lower. Return count and latest inferred time without claiming provider-confirmed reset causality.
- [ ] Aggregate refresh outcomes from diagnostics in the selected range. Treat confirmed and confirmed-after-retry as confirmed; keep cached-last-known-good separate; group unconfirmed and unavailable together.
- [ ] Calculate data age only from `lastConfirmedAt`. Preserve cached/paused mode from `QuotaDisplayState`; analytics never decides freshness itself.
- [ ] Confirm with a source audit that the produced snapshot exposes no account identity, credit, limit-ID, failure-kind, or raw-error property.

### Task 4: Publish analytics without blocking SwiftUI

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardViewModel.swift`

**Interfaces:**
- Consumes: `DashboardAnalyticsService`, `QuotaDisplayState`, and user range selections.
- Produces: `@Published private(set) var snapshot`, `@Published var selectedRange`, and `func reload(displayState:)` for `DashboardView`.

- [ ] Make the view model `@MainActor` and keep the analytics service actor-isolated so file decoding and calculations do not run inside a SwiftUI `body`.
- [ ] Default `selectedRange` to `.week`; range persistence is intentionally out of scope.
- [ ] Cancel an obsolete reload task before starting another, and assign a snapshot only when the task is not cancelled.
- [ ] Reload when the Dashboard first appears, when the selected range changes, and when `QuotaViewModel.displayState` publishes a new attempt or confirmed record.
- [ ] Preserve the last complete snapshot while a reload is in progress and publish a lightweight loading flag instead of clearing metrics to zero.

### Task 5: Render one functional combined Dashboard

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardStatusBanner.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardLaneCard.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardHistoryChart.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Dashboard/DashboardOutcomeView.swift`

**Interfaces:**
- Consumes: `QuotaViewModel`, `DashboardViewModel`, and the immutable dashboard snapshot types.
- Produces: one scrollable, accessible native SwiftUI dashboard surface.

- [ ] Put the range picker in the window toolbar or top content row with the exact choices 24 hours, 7 days, 30 days, and 90 days.
- [ ] Render a full-width status banner before metrics. Confirmed/completed identifies current data; cached/paused uses text plus an icon and last-confirmed time so state is distinguishable without relying on color; unavailable explains that no confirmed snapshot exists.
- [ ] Render separate five-hour and weekly cards with current remaining/used percentage, reset countdown/time, consumption per hour, sustainable pace, forecast/confidence/observation count, and 15-minute/1-hour/24-hour changes. Every unavailable metric shows its stored explanation rather than `0` or `—` without context.
- [ ] Render one combined Swift Charts history area with lane controls or a clear legend. Use both lane and `resetWindowID` as the line series identity so each reset window is a separate segment.
- [ ] Add chart accessibility summaries describing range, available lanes, observation counts, and min/max usage; do not require VoiceOver to traverse every mark to understand the chart.
- [ ] Render refresh outcome rates, data age, inferred reset count, and latest inferred reset time below the charts.
- [ ] Keep credits, reset-credit expiration, account fingerprint, limit ID, and plan identity out of the Dashboard.
- [ ] Use flexible stacks, system text styles, semantic foreground styles, monospaced digits for changing numeric values, and vertical scrolling. Do not introduce a custom theme or Figma styling.

### Task 6: Add the separate focusable window and native menu command

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`

**Interfaces:**
- Consumes: the shared app-owned `QuotaViewModel` and SwiftUI `openWindow` action.
- Produces: one `Window` scene with identifier `dashboard` and one inline **Dashboard…** menu command.

- [ ] Add `Window("Dashboard", id: "dashboard")` rather than `WindowGroup` so repeated opens target one dashboard window.
- [ ] Give the window a practical default size and a smaller minimum size while allowing user resizing; apply the shared System/Light/Dark preference.
- [ ] Add **Dashboard…** as a native inline command above **Settings…** in both connected and disconnected menu stages. Activate the app and call `openWindow(id: "dashboard")` without changing menu presentation style.
- [ ] Keep **Settings…** and **Quit Codex Usage Monitor** as the final shared commands.
- [ ] Confirm the Dashboard calls no repository refresh itself; it observes the same monitor refreshes used by the menu and Settings.

### Task 7: Document and verify the Dashboard branch

**Files:**
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `docs/superpowers/plans/2026-07-14-dashboard.md`

**Interfaces:**
- Consumes: the signed app and existing sanitized local stores.
- Produces: implementation status, user operating instructions, privacy notes, and dated acceptance evidence.

- [ ] Document how to open Dashboard, change ranges, interpret confirmed/cached/unavailable status, read reset-separated chart segments, and understand unavailable metrics.
- [ ] Document that Dashboard is read-only, uses existing refresh timing, excludes credits and identity, and does not trigger extra Codex reads.
- [ ] Run `bash Scripts/build-app.sh` from `CodexUsageMonitor`; record the completed signed bundle.
- [ ] Run `codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app`; record valid-on-disk and designated-requirement results.
- [ ] Inspect the signed Dashboard at its default and minimum sizes in Light and Dark appearance. Check status differentiation, wrapping, chart clipping, range switching, empty history, one missing lane, cached/paused, and unavailable states.
- [ ] Open Dashboard repeatedly from the native menu and confirm one window is focused rather than duplicated.
- [ ] Compare 24-hour, 7-day, 30-day, and 90-day ranges against sanitized retained timestamps without logging account identifiers or quota values in the plan.
- [ ] Record any unavailable visual or operational acceptance honestly; compilation is not a substitute for signed-app UI inspection.

## Self-review

- Spec coverage: the plan includes one separate window, four required ranges, current limits, reset countdowns, reset-separated charts, consumption and sustainable rates, forecast evidence, three change horizons, outcome rates, data age, inferred resets, cached/paused treatment, focus behavior, and privacy exclusions.
- Scope control: no credits, export/delete, provider additions, settings redesign, Figma theme, CloudKit, widgets, account display, or extra refresh timer is included.
- Type consistency: the stores produce filtered entries; the actor produces `DashboardSnapshot`; the main-actor view model publishes it; views consume only the snapshot plus shared display state; the app owns window creation.
- Verification constraint: no automated test cases or commands are included, matching the repository's explicit rule. Signed builds, source/privacy audits, bounded store inspection, and manual UI acceptance are the evidence path.
