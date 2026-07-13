# Codex Daily-Driver Roadmap

> **For agentic workers:** Implement one branch at a time with `executing-plans`. Do not generate or run automated tests; use compilation, read-only live collection, schema inspection, and manual UI acceptance. Update `outline.md`, `how-to.md`, `UsageProbe/README.md`, and the active plan whenever behavior changes.

**Goal:** Turn the proven Codex quota monitor into a dependable daily-driver with configurable warnings, adaptive refresh, safe account connection, separate Settings and Dashboard windows, and launch at login before adding another provider.

**Architecture:** Keep `QuotaRepository.refresh() -> QuotaRecord` as the collection seam and `QuotaMonitor` as the scheduling seam. Add small persisted settings and analytics interfaces consumed by the menu, Settings, Dashboard, notifier, and scheduler; provider-specific authentication remains behind a Codex connection module. No later UI calls Codex or reads persistence directly.

### Cross-cutting quota presentation state

All current and future UI surfaces must consume one provider-neutral `QuotaDisplayState` published by monitoring. Views must not infer freshness independently from provider confirmation strings, error copy, timestamps, or cache source fields.

```swift
enum QuotaDisplayMode: String, Codable, Sendable {
    case confirmedCompleted = "confirmed-completed"
    case cachedPaused = "cached-paused"
}

struct QuotaDisplayState: Sendable {
    let mode: QuotaDisplayMode
    let displayedRecord: QuotaRecord?
    let lastAttemptAt: Date
    let lastConfirmedAt: Date?
    let pauseReason: QuotaPauseReason?
}

enum QuotaPauseReason: String, Codable, Sendable {
    case cachedLastKnownGood = "cached-last-known-good"
    case unconfirmed
    case unavailable
    case repeatedFailures = "repeated-failures"
}
```

The two user-facing modes are:

- **Confirmed / completed:** the most recent refresh completed and produced a trusted live result (`confirmed` or `confirmed-after-retry`). Render the current record normally and identify the successful refresh time.
- **Cached / paused:** the most recent refresh did not produce a trusted live result. Preserve and visibly label the last confirmed record when one exists, show both the last attempt and last successful refresh, and explain the normalized pause reason. Never present cached values as current. If no last-confirmed record exists, render the same mode with an unavailable state rather than inventing zero usage.

`QuotaMonitor` owns transitions and timestamps. `QuotaViewModel` remains a shallow UI adapter. The menu popover, Dashboard, future widgets, Watch surfaces, exports, and additional provider adapters must render this same contract so a later UI redesign cannot silently reinterpret stale data.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Charts, ServiceManagement, UserNotifications, Foundation JSON persistence, Codex app-server/CLI; no third-party dependencies or proprietary backend.

## Global constraints

- Codex first. Defer Claude and GitHub Copilot until the Codex daily-driver release passes acceptance.
- Do not read `auth.json`, store tokens, accept passwords, replay callback URLs, send prompts, or consume reset credits.
- Do not create or run automated tests for these branches.
- Keep fixed remaining-quota thresholds at 50%, 25%, 10%, and 5%.
- Manual refresh choices are 1 minute, 1 minute 30 seconds, 2 minutes (default), 5 minutes, and 10 minutes.
- Automatic refresh may use 30 seconds only around an imminent threshold, qualified exhaustion, or reset verification.
- Keep credits and earned reset-credit details in the menu popover, not the Dashboard.
- Dashboard ranges are 24 hours, 7 days (default), 30 days, and 90 days; never draw a continuous series across reset windows.
- Export and destructive data-management controls are deferred.
- Each feature branch includes documentation changes and a fresh Swift build.

## Gate 0: reliability correction

The existing seven-day hardening evidence is deferred. Before release, create `fix/codex-reliability` if observation shows repeated fallback, unstable reset timestamps, or refresh overlap. Feature work may proceed now, but `release/codex-daily-driver` cannot pass until the observation findings are recorded.

## Branch sequence

### 1. `feature/notification-settings` — merged

Deliver the separate Settings window shell and persisted warning controls. Existing 50/25/10/5 threshold, qualified forecast, and reset-credit-expiry notifications must respect their controls. Add monitor-driven reset-completed, reset-failed, stale-data, and repeated-refresh-failure events plus quiet hours with a critical-warning override.

Acceptance: settings survive relaunch; notification authorization is requested only from an explicit user action; cached/unconfirmed data never drives forecast alerts; fixed thresholds remain unchanged.

### 2. `feature/settings-foundation` — active

Add General, Refresh, Agents, Data & Privacy, and Diagnostics tabs to the existing Settings window. Agents uses a left provider sidebar and an in-tab detail pane for each agent: Codex is the current integration, while Claude Code and GitHub Copilot are planned and not connected. Show retention and privacy information without export/delete actions. Keep all settings behind one persisted settings module rather than reading `UserDefaults` throughout views.

Acceptance: one Settings window is focused on repeated opens; `Command-,` works; every control changes real behavior or is read-only status.

### 3. `feature/adaptive-refresh` — active (stacked on Settings Foundation)

Replace the fixed timer with a scheduling policy returning an effective interval and explanation. Fixed modes use 60/90/120/300/600 seconds. Automatic considers confirmed consumption slope, remaining percentage, reset proximity, forecast confidence, and recent failures. It may use 30 seconds for at most ten minutes and exits after the event or two failures. Add `nextRefreshAt`, effective-mode explanation, and the provider-neutral `QuotaDisplayState` to monitoring state; show a live countdown beside Last refresh and the two-state confirmed/completed or cached/paused status in the popover.

Acceptance: manual refresh never waits behind scheduled work; only one collection runs; repeated failures fall back to five minutes; wake and launch always refresh. Confirmed-after-retry is confirmed/completed; cached, unconfirmed, and unavailable outcomes are cached/paused without replacing the last confirmed display record.

### 4. `feature/codex-connection`

Add a Codex connection module that distinguishes missing CLI, unauthenticated, connected, signing in, and failed states. Primary “Sign in with browser” uses provider-generated app-server authentication URLs and completion events. Secondary CLI flow visibly opens Terminal with `codex login` ready for the user to run, then monitors `codex login status`. Omit logout and account switching.

Acceptance: neither path reads credentials; successful sign-in triggers a quota refresh; missing Codex shows installation guidance; failures remain recoverable.

### 5. `feature/dashboard`

Add one separate Dashboard window using Swift Charts and a read-only analytics module. Include current five-hour/weekly percentages, reset countdowns, reset-separated usage charts, consumption per hour, forecast/confidence/observation count, sustainable pace, 15-minute/1-hour/24-hour changes, refresh outcome rates, data age, and inferred reset history. Exclude credit balance and earned reset credits.

Acceptance: ranges are 24h/7d/30d/90d with 7d default; no account fingerprint is displayed; missing evidence produces an unavailable explanation rather than zero; repeated opens focus one window.

Dashboard acceptance also requires rendering `QuotaDisplayState` directly: cached/paused data must remain visually distinguishable from the latest confirmed history and must show its last-successful timestamp.

### 6. `feature/general-preferences`

Add an opt-in **Launch at Login** General setting backed by `SMAppService.mainApp`. Default off, show actual registration state, and surface registration errors without changing the preference silently. Add an **Appearance** picker with **System** (default), **Light**, and **Dark** choices, persisted through `AppSettings`; apply the selected scheme to app-owned windows without attempting to recolor native macOS menu-bar chrome.

Acceptance: enabling launch at login registers the app, disabling unregisters it, and fresh installs remain off. Appearance defaults to System, updates open app windows immediately, and persists after relaunch.

### 7. `feature/menu-bar-display`

Add a General setting for the compact menu-bar label. Preserve the existing gauge as one option, but allow the user to replace it with a live numeric remaining-usage label or another compact provider-neutral style.

```swift
enum MenuBarDisplayStyle: String, Codable, CaseIterable, Sendable {
    case gaugeAndLowestRemaining = "gauge-and-lowest-remaining"
    case lowestRemainingPercent = "lowest-remaining-percent"
    case fiveHourRemaining = "five-hour-remaining"
    case weeklyRemaining = "weekly-remaining"
    case providerAndRemaining = "provider-and-remaining"
    case iconOnly = "icon-only"
}
```

Behavior:

- **Gauge and lowest remaining:** retain the current gauge plus the lowest available remaining percentage.
- **Lowest remaining percentage:** show a compact live value such as `64%`, without the speedometer.
- **Five-hour remaining / weekly remaining:** pin the label to one chosen quota lane.
- **Provider and remaining:** show compact provider context such as `C 64%`; the provider abbreviation comes from normalized presentation metadata rather than a Codex-specific view condition.
- **Icon only:** show the selected system icon without percentage text.
- Update immediately after every accepted display-state transition and whenever the preference changes; do not wait for the popover to open.
- Consume `QuotaDisplayState`. In cached/paused mode, retain the last confirmed percentage but add a compact pause/stale marker and accessibility label. When no confirmed value exists, display `—` rather than `0%`.
- Provide a small preview for every style in Settings. Use native SwiftUI text and SF Symbols for menu-bar legibility; defer imported/custom artwork until signing, asset, light/dark appearance, and template-image behavior are proven.
- Keep the initial scope to the styles above. Later extensions may add user-selected system icons, used-versus-remaining display, lane rotation, color/urgency accents where macOS permits them, and multi-provider lowest-remaining mode.

Acceptance: the numeric label changes after a confirmed refresh; switching styles updates immediately; five-hour/weekly modes handle a missing lane without inventing a value; cached/paused mode is visibly distinct; VoiceOver describes provider, lane, percentage, and freshness; the menu-bar label remains readable in light and dark appearances.

### 8. `feature/figma-ui-overhaul`

Run a frontend-only Figma-to-SwiftUI overhaul after the functional Settings, Dashboard, General preferences, and menu-bar display branches have stable interfaces. Entry requires an approved Figma `/design/` URL with specific screen nodes or an explicit Figma Desktop selection. Use Figma MCP design context, screenshots, variables, asset inventory, and Code Connect mappings; perform an element-by-element adaptation audit before changing existing SwiftUI.

Scope the overhaul to app-owned windows and reusable presentation components. Settings and Dashboard may adopt the Figma layout, tokens, typography, and exported assets while continuing to consume the existing provider-neutral state and action interfaces. Keep the menu-bar extra in native menu presentation unless a separate decision explicitly approves window style; a Figma mockup must not silently turn inline menu commands into panel buttons.

Acceptance: every implemented screen has a recorded Figma node and source screenshot; light and dark appearances, Dynamic Type, VoiceOver labels, confirmed/completed, cached/paused, unavailable, loading, and error states are represented; no view reads provider services or persistence directly; all existing working controls retain behavior; exported assets are validated and documented; manual side-by-side visual review is recorded. This branch must not change quota collection, scheduling, authentication, notification policy, or storage schemas.

### 9. `release/codex-daily-driver`

Reconcile all branch plans and docs, finish the seven-day reliability gate, build the app bundle, and run the complete manual acceptance checklist. Record deferred work: export/delete, logout/account switching, arbitrary thresholds, widgets, CloudKit/Watch, signing/notarization/updater, Claude, and Copilot.

## Later provider branches

After the Codex release, create independent research branches before implementations:

1. `research/copilot-capability` then `feature/copilot-provider` only if an official personal allowance path is verified.
2. `research/claude-local-analytics` then `feature/claude-local-analytics`; quota remains experimental until separately proven.
3. Deepen the provider seam only when the second real adapter exists; do not design speculative provider interfaces now.

## Documentation rule

Every merged branch must update its plan checkboxes, `outline.md` phase status, `how-to.md` user instructions, and `UsageProbe/README.md` when the native companion’s behavior or privacy boundary changes.
