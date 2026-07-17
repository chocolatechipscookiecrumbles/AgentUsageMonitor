# Codex Daily-Driver Roadmap

> **For agentic workers:** Implement one branch at a time with `executing-plans`. Add focused automated coverage for deterministic seams and use compilation, read-only live collection, schema inspection, signed-app inspection, and manual UI acceptance in proportion to the claim. Update `outline.md`, `how-to.md`, `UsageProbe/README.md`, and the active plan whenever behavior changes.

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

## Authoritative plan status — reconciled 2026-07-17

| Plan | Current state | Remaining gate |
| --- | --- | --- |
| Capability probe | Complete historical research | None |
| Menu-bar MVP | Complete; superseded by follow-ons | None |
| Quota history foundation | Complete; superseded by reliability contract | None |
| Reliability hardening | Implementation complete; observation active | Natural forecast/failure evidence and seven corrected calendar days |
| Notification settings | Implemented | Permission/persistence/natural-event manual acceptance |
| Settings foundation and follow-ups | Implemented; superseded visually by Figma Settings port | Conditional states, shortcuts; Launch at Login skipped |
| Adaptive refresh | Event-driven absolute-time repair implemented and accepted for the scrolling/highlight regression | Settings mode switching and natural cached/paused acceptance remain; a true live countdown is separately deferred |
| Codex connection | Implemented and user-accepted | No account mutation required |
| Menu-bar display and placement | Implemented | Immediate preview, missing/cached lane, width, and VoiceOver checks |
| Interruption backoff | Implemented with one delivery-durability follow-up | Retry the same stable event after failed submission, then controlled outage/recovery and signed-out/missing-CLI acceptance |
| Dashboard | Deferred by user; partial historical checklist retained | Resume the recovered [Dashboard plan](2026-07-14-dashboard.md) only on explicit direction and after revalidating it against current `main` |
| Figma Settings global sidebar | Implemented; signed Light/Dark appearance-transition acceptance complete | Inspect remaining manufactured conditional states in `2026-07-15-settings-system-appearance-transition.md` |
| Settings and multi-agent follow-ups | Planned; documentation only | Split and revalidate the recovered [Settings and multi-agent follow-ups plan](2026-07-14-settings-provider-followups.md) after explicit direction and applicable provider capability work |
| Settings section sidebars | Implemented historical stage; superseded by the global sidebar | Retain the recovered [section-sidebars plan](2026-07-14-settings-section-sidebars.md) as provenance; do not resume its old geometry without re-scoping |
| Compact Settings and menu placement | Implemented historical stage; visually superseded | Retain the recovered [compact Settings/menu-placement plan](2026-07-14-compact-settings-menu-placement.md) as provenance; the separate native refresh-row regression remains active above |
| Other Figma surfaces | Deferred | Menu popover, widgets, and Watch require separate user direction |

## Global constraints

- Codex first. Defer Claude and GitHub Copilot until the Codex daily-driver release passes acceptance.
- Do not read `auth.json`, store tokens, accept passwords, replay callback URLs, send prompts, or consume reset credits.
- Add the smallest deterministic automated regression coverage permitted by the current repository rules; keep signed macOS UI and permission checks as separate manual evidence.
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

Deliver the separate Settings window shell and persisted warning controls. Existing 50/25/10/5 threshold, qualified forecast, and reset-credit-expiry notifications must respect their controls. Add monitor-driven reset-completed, reset-failed, stale-data, and extended-interruption events. The originally implemented quiet-hours override was retired on 2026-07-14 in favor of macOS Focus and notification settings. The interruption follow-up sends one cautious notice on the third consecutive unsuccessful refresh, suppresses overlapping stale-data notices, and persists the episode identity across relaunches.

Acceptance: settings survive relaunch; notification authorization is requested only from an explicit user action; cached/unconfirmed data never drives forecast alerts; fixed thresholds remain unchanged.

### 2. `feature/settings-foundation` — implemented; superseded visually by later Settings work

Add General, Refresh, Agents, Data & Privacy, and Diagnostics tabs to the existing Settings window. Agents uses a left provider sidebar and an in-tab detail pane for each agent: Codex is the current integration, while Claude Code and GitHub Copilot are planned and not connected. Show retention and privacy information without export/delete actions. Keep all settings behind one persisted settings module rather than reading `UserDefaults` throughout views.

Acceptance: one Settings window is focused on repeated opens; `Command-,` works; every control changes real behavior or is read-only status.

### 3. `feature/adaptive-refresh` — implemented (stacked on Settings Foundation)

Replace the fixed timer with a scheduling policy returning an effective interval and explanation. Fixed modes use 60/90/120/300/600 seconds. Automatic considers confirmed consumption slope, remaining percentage, reset proximity, forecast confidence, and recent failures. It may use 30 seconds for at most ten minutes and exits after the event or two failures. Add `nextRefreshAt`, effective-mode explanation, and the provider-neutral `QuotaDisplayState` to monitoring state; show the absolute next-refresh time beside Last refresh and the two-state confirmed/completed or cached/paused status in the popover. The native row changes only for semantic refresh/schedule transitions, not once per elapsed second.

Acceptance: manual refresh never waits behind scheduled work; only one collection runs; the first two failures keep the existing fixed cadence (Automatic may fall back to five minutes), while the third starts a temporary ten-minute retry cadence in every mode; wake and launch always refresh. Confirmed-after-retry is confirmed/completed; cached, unconfirmed, and unavailable outcomes are cached/paused without replacing the last confirmed display record.

### 4. `feature/codex-connection` — implemented and user-accepted (stacked on Adaptive Refresh)

Add a Codex connection module that distinguishes missing CLI, unauthenticated, connected, signing in, and failed states. Primary “Sign in with browser” uses provider-generated app-server authentication URLs and completion events. Secondary CLI flow visibly opens Terminal with `codex login` ready for the user to run, then monitors `codex login status`. Omit logout and account switching.

Acceptance: neither path reads credentials; successful sign-in triggers a quota refresh; missing Codex shows installation guidance; failures remain recoverable.

Implementation status on 2026-07-13: the provider-neutral connection state, `account/read` detection, Codex-managed browser flow, visible Terminal CLI flow, explicit disconnected menu stage, and Agents Settings connection detail are implemented. The native menu renders exactly one of two top-level stages: connected quota controls, or connection guidance/actions; Settings and Quit remain the final shared commands. Compilation, confirmed live collection, signed-bundle launch, and isolated disconnected-process survival passed, and user-reported manual acceptance confirmed the disconnected menu plus successful browser/CLI transitions. The app does not log out the current account automatically to manufacture that state.

### 5. `feature/menu-bar-display` — implemented; manual UI acceptance pending (stacked on Codex Connection)

Implement the dynamic General-controlled menu-bar display described below before returning to the remaining Settings and Dashboard sequence.

Detailed plan: `docs/superpowers/plans/2026-07-13-menu-bar-display.md`.

Add a **Menu Bar** section to General with two independent preferences: **Appearance** chooses the label layout, and **Show** chooses whether every percentage represents quota **Remaining** or **Used**. Preserve the current gauge as the default appearance and add one dual-limit appearance that shows both quota lanes at once.

```swift
enum MenuBarDisplayStyle: String, Codable, CaseIterable, Sendable {
    case gaugeAndLowest = "gauge-and-lowest"
    case fiveHourAndWeekly = "five-hour-and-weekly"
}

enum QuotaValueMode: String, Codable, CaseIterable, Sendable {
    case remaining
    case used
}
```

Behavior:

- In General, label the layout picker **Appearance** with choices **Gauge** and **5-hour and weekly**.
- Label the value-mode picker **Show** with choices **Remaining** and **Used**. Use an explicit two-choice picker rather than a switch whose off state is hidden. Default to **Remaining** for compatibility with the current display.
- **Gauge:** retain the current gauge and show the most-consumed available lane: minimum remaining in Remaining mode or maximum used in Used mode.
- **5-hour and weekly:** render `5H: 64% | Week: 82%` in Remaining mode. In Used mode, render the complements, for example `5H: 36% | Week: 18%`.
- Calculate used percentage as `100 - remaining`, clamp to 0...100, and use the same whole-percent rounding rule for both modes.
- If one lane is unavailable, preserve the label structure and show `—` for only that lane, such as `5H: 64% | Week: —`. Never substitute `0%` for unavailable data.
- Update immediately after every accepted display-state transition and whenever the preference changes; do not wait for the popover to open.
- Consume `QuotaDisplayState`. In cached/paused mode, retain the last confirmed values but add a compact pause/stale marker and accessibility description. When no confirmed value exists, display `—` for both lanes.
- Give the dual label a semantic accessibility value such as “5-hour limit, 64 percent remaining; weekly limit, 82 percent remaining” instead of reading the visual separator aloud.
- Provide a live preview for both appearances and both value modes in General. Use native SwiftUI text, monospaced digits, and SF Symbols for menu-bar legibility; verify the maximum `5H: 100% | Week: 100%` label does not clip in light or dark appearance.
- Keep the initial scope to these two appearances. Later extensions may add lowest-only, single-lane, provider-and-remaining, icon-only, user-selected system icons, lane rotation, color/urgency accents where macOS permits them, and multi-provider lowest-remaining mode.

Acceptance: the dual label shows both lanes in the requested format; switching Appearance or Show updates immediately; Remaining and Used are complementary; a missing lane never invents a value; cached/paused mode is visibly distinct; VoiceOver describes both lanes, value mode, and freshness; and the maximum-width label remains readable in light and dark appearances.

Implementation status on 2026-07-13: persisted Appearance and Show preferences, provider-neutral label formatting, cached/paused marking, semantic accessibility text, reactive `MenuBarExtra` rendering, and the General live preview compile and produce a valid signed app. A newly launched signed instance survived its launch refresh without a new crash report. Visual switching, preference relaunch, and one full scheduled interval remain manual acceptance checks.

### 6. `feature/settings-ui-followups` — implemented; manual UI acceptance pending (stacked on Menu Bar Display)

Refine the existing Settings window before adding Dashboard. Replace the combined remaining-quota warning switch with separate 50%/25%/10%/5% choices that apply to both quota lanes. Turning off **Enable quota notifications** must grey every subordinate notification control without erasing choices. Expand General with working **Launch at login**, **System/Light/Dark** appearance, and app-local keyboard-shortcut enablement. Rebuild the Agents tab as a lower-content-only split so its provider sidebar begins below, and never takes space from, the unchanged full-width top Settings tab bar.

Acceptance: threshold choices persist and filter delivery independently; the notification master switch gates and greys the checklist while permission recovery remains active; Launch at Login reflects real `SMAppService` state; appearance updates app-owned windows; disabling shortcuts removes the custom `Command-R` refresh binding but not standard Settings/Quit commands; and switching tabs never moves or narrows the top tab bar.

Detailed plan: `docs/superpowers/plans/2026-07-13-settings-ui-followups.md`.

Implementation status on 2026-07-13: typed per-threshold persistence and confirmed-live delivery filtering, master disabled-state hierarchy, real `SMAppService.mainApp` Launch at Login handling, persisted System/Light/Dark appearance, conditional app-local `Command-R`, and the lower-only Agents sidebar compile and produce a valid signed app. Strict signature and plist validation passed, and a temporary signed instance survived its launch refresh without a new crash report. Visual interaction, persistence relaunch, actual Login Items mutation, and complete tab-layout inspection remain manual acceptance checks.

### 7. `feature/dashboard`

Add one separate Dashboard window using Swift Charts and a read-only analytics module. Include current five-hour/weekly percentages, reset countdowns, reset-separated usage charts, consumption per hour, forecast/confidence/observation count, sustainable pace, 15-minute/1-hour/24-hour changes, refresh outcome rates, data age, and inferred reset history. Exclude credit balance and earned reset credits.

Acceptance: ranges are 24h/7d/30d/90d with 7d default; no account fingerprint is displayed; missing evidence produces an unavailable explanation rather than zero; repeated opens focus one window.

Dashboard acceptance also requires rendering `QuotaDisplayState` directly: cached/paused data must remain visually distinguishable from the latest confirmed history and must show its last-successful timestamp.

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
