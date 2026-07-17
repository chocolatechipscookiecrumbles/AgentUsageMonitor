# Native Menu Refresh Row Implementation Plan

> **Status (2026-07-17): Repair implemented and accepted for the reported regression.** Task 1 is reconciled against current `main`. The per-second child observation has been replaced by event-driven absolute-time presentation without adding test cases, per user direction. Connected/scheduled rendering and the original pointer/scroll highlight path passed signed-app inspection; unmanufactured conditional states remain recorded limitations rather than inferred coverage.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Do not treat an isolated SwiftUI host as final UI evidence; every accepted rendering change requires the signed app's actual `MenuBarExtra`.

**Goal:** Make the native menu's refresh-timing row semantically current without reviving stale highlighting, incorrect hit-testing, recursive invalidation, or crashes.

**Architecture:** Keep `QuotaMonitor` and `QuotaViewModel` as the scheduling and UI-state owners, but replace the independently observed countdown child with one immutable, event-driven `MenuRefreshTimingPresentation` consumed by the already-observed menu root. Preserve the native menu's structure and show an absolute next-refresh time rather than a relative value that appears to count down while frozen. If a true per-second countdown remains a product requirement, evaluate it later as an explicit AppKit-owned fixed-geometry menu architecture, not as a one-line observation rollback.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, AppKit, macOS 14+; native `MenuBarExtra` for the recommended repair and a signed `.app` for final visual acceptance.

## Global Constraints

- Preserve the existing native pull-down menu, inline commands, ordering, visual language, and compact footprint for the recommended repair.
- Do not restore a child-level `@ObservedObject`, `TimelineView`, timer-interval `Text`, or per-second root invalidation as the production fix.
- Keep row count, row identity, control type, and geometry stable while the menu is tracking.
- Refresh-start, refresh-completion, cached/paused, and next-schedule changes are correctness transitions and must update; per-second elapsed-time animation is secondary.
- Do not modify collection cadence, refresh scheduling, quota trust semantics, notification behavior, or Settings behavior.
- Do not add test cases. Use source tracing, the existing test suite, warning-clean compilation, signed-app inspection, interaction checks, and crash-report inspection in proportion to each claim.
- Do not claim success from compilation, unit tests, or `NSHostingView`; inspect the actual signed `MenuBarExtra` through the full interaction matrix.
- Preserve user-owned processes and follow the repository GUI audit safety instructions.

---

### Task 1: Establish the coupled failure baseline

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-native-menu-refresh-row.md`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NextRefreshCountdownView.swift`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/RefreshCountdownClock.swift`
- Inspect: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Consumes: `QuotaMonitor.$displayState`, `QuotaMonitor.$refreshState`, `QuotaMonitor.$nextRefreshAt`, and the current menu row tree.
- Produces: recorded baseline evidence for both rendering freshness and AppKit row placement.

- [x] **Step 1: Record the state and observation path**

The current chain is `QuotaMonitor publishers -> QuotaViewModel sinks -> countdownClock.update(...) -> RefreshCountdownClock.$text -> @ObservedObject NextRefreshCountdownView -> MenuBarExtra`. The clock publishes a different relative-countdown string every second, and the child view independently invalidates while AppKit is tracking the open native menu. The countdown therefore updates, but the native menu's row geometry and highlight map can drift apart.

- [x] **Step 2: Reproduce both historical failure modes**

The user confirmed the current signed-app behavior on 2026-07-17: the countdown and refresh/menu transitions work, while scrolling below the intended menu area can move the highlight to an earlier row. Git history supplies the coupled comparison: commit `56a1595` removed `@ObservedObject` from the countdown child and the user accepted the pointer/scroll repair on 2026-07-14; current `main` again observes the child once per second and the same interaction regression has returned. Earlier diagnostic reports also retain the separate recursive-invalidation crash history from timer-driven menu rendering.

The isolated baseline app built and launched as audit PID 48941 without terminating the pre-existing user-owned PID 29637. Accessibility could read the audit status item but denied UI control with error `-1719`. A coordinate-based fallback was abandoned immediately after it did not target the status item reliably, and only PID 48941 was closed. The user's direct reproduction is therefore the baseline interaction evidence; no automated click result is treated as visual acceptance.

- [x] **Step 3: Create the acceptance matrix before implementation**

| State | Timing/status presentation | Stable structure and enabled actions | Expected transition |
| --- | --- | --- | --- |
| Connected, scheduled | `Last refresh: <time> · Next refresh: <time>` | Exactly one plain timing row; Refresh, Settings, and Quit retain their current order | Refresh start replaces text in the same row |
| Refreshing | `Last refresh: <time> · Refreshing…` | Same timing-row identity; Refresh is disabled; Settings and Quit remain available | Completion replaces text in the same row without per-second invalidation |
| Confirmed completion | `Confirmed / completed` plus the scheduled absolute time | Existing quota rows remain current; command order is unchanged | The next schedule is shown as an absolute time |
| Cached/paused completion | `Cached / paused`, normalized reason, last successful time when available, and the scheduled absolute time | Last confirmed quota remains visibly cached; timing row remains one row | Confirmed recovery restores normal status without changing command placement |
| Deadline reached or schedule temporarily absent | `Last refresh: <time> · Scheduling…` until refresh/scheduling publishes a semantic replacement | Same timing-row identity and menu width envelope | Becomes Refreshing or Scheduled through monitor-owned state |
| Disconnected | No connected timing row | Existing sign-in actions appear; Settings and Quit remain the final shared commands | Successful connection enters the connected row tree |
| Notifications denied | Current standalone denial text and recovery button | Recovery button remains above Refresh; no overlap with timing metadata | Authorization changes remove only the conditional recovery rows |
| Missing quota lane | Existing unavailable copy for that lane | Missing values never become `0%`; commands remain reachable | A later confirmed lane replaces only its quota content |
| Long/localized copy | One readable or natively truncated line inside a stable width envelope | No control overlap, row displacement, or off-target highlight | Semantic replacement does not resize the tracked menu |

For every connected state, pointer highlighting must match the visible row before and after scrolling above/below Quit. The menu's outer frame and the timing row's frame must not jump during refresh start or completion.

- [x] **Step 4: Stop for a pre-code review checkpoint**

Checkpoint result: the smallest repair is the planned immutable semantic presentation consumed by the already-observed menu root, with an absolute next-refresh time and no independently observed/ticking child. It preserves refresh scheduling and native command semantics. The user explicitly approved proceeding with this repair and required visual inspection; no AppKit menu rewrite or window-style popover is authorized.

---

### Task 2: Replace the ticking child with an event-driven presentation contract

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuRefreshTimingPresentation.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState.lastAttemptAt`, `RefreshState`, and `QuotaMonitor.nextRefreshAt`.
- Produces: `MenuRefreshTimingPresentation` and `QuotaViewModel.refreshTimingPresentation`.

- [x] **Step 1: Define one immutable semantic value**

Use a value whose equality changes only for meaningful menu content:

```swift
struct MenuRefreshTimingPresentation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case refreshing
        case scheduled(nextRefreshAt: Date)
        case scheduling
    }

    let lastRefreshAt: Date
    let phase: Phase

    init(lastRefreshAt: Date, refreshState: RefreshState, nextRefreshAt: Date?) {
        self.lastRefreshAt = lastRefreshAt
        phase = switch refreshState {
        case .refreshing:
            .refreshing
        case .idle, .failed:
            nextRefreshAt.map(Phase.scheduled) ?? .scheduling
        }
    }
}
```

The type contains dates and phase only. It owns no timer, publisher, view, localized formatter, or collection logic.

- [x] **Step 2: Trace the focused semantic transitions without adding tests**

Inspect the constructor and view-model sinks for idle-to-refreshing, refreshing-to-scheduled, scheduled-time replacement, cached/paused completion, and no-next-date scheduling. Record the source path and confirm the signed menu performs the observable transitions in Task 4. Do not create a test target file for this task.

Source trace: `MenuRefreshTimingPresentation` maps `.refreshing` to `.refreshing`; `.idle`/`.failed` plus a deadline to `.scheduled`; and `.idle`/`.failed` without a deadline to `.scheduling`. `QuotaViewModel` recomputes after display-state, refresh-state, and next-schedule publications, suppressing equal values. Cached/paused completion changes the attempt timestamp and status through the same monitor-owned path without changing timing ownership.

- [x] **Step 3: Publish from the existing view-model boundary**

Add `@Published private(set) var refreshTimingPresentation` to `QuotaViewModel`. Recompute it after the relevant monitor sinks update, ensuring one coherent final value per semantic transition. Do not publish once per elapsed second.

- [x] **Step 4: Verify the domain slice**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors
```

Result: the warnings-as-errors build completed successfully on 2026-07-17. Compilation proves type and concurrency coherence only; it does not satisfy native-menu visual acceptance.

---

### Task 3: Render truthful, fixed-geometry native-menu copy

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift`
- Replace: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NextRefreshCountdownView.swift` with `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuRefreshTimingView.swift`
- Remove if unused: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/RefreshCountdownClock.swift`

**Interfaces:**
- Consumes: `QuotaViewModel.refreshTimingPresentation` through the existing `@ObservedObject` root.
- Produces: one stable plain-text native-menu row.

- [x] **Step 1: Keep one row in every connected timing phase**

Render one `Text` at the same position for refreshing, scheduled, and scheduling. Do not conditionally insert a replacement view, change the row into a button, or attach a child-level observable object.

- [x] **Step 2: Use copy that matches its update semantics**

Render:

- `Last refresh: 23:31 · Refreshing…`
- `Last refresh: 23:31 · Next refresh: 23:33`
- `Last refresh: 23:31 · Scheduling…`

The scheduled form uses an absolute time because it remains truthful without per-second invalidation. Do not display `Next: 1:42` unless it actually advances while open.

- [x] **Step 3: Preserve accessibility and width behavior**

Keep the row a single accessibility element with semantic text and disable implicit animation for its semantic replacement. Inspect the longest supported time representation and verify the menu's outer frame and every row frame remain stable during a semantic transition. If the timing row controls menu width, reserve one constant layout envelope for all three phase strings rather than allowing the tracked menu to resize.

- [x] **Step 4: Remove obsolete ticking ownership only after reference inspection**

`rg` confirms there is no remaining `RefreshCountdownClock`, `countdownClock`, `NextRefreshCountdownView`, one-second menu timer, `TimelineView`, or timer-interval `Text` under application sources/tests. `QuotaMonitor`'s one-shot refresh scheduler is unchanged.

---

### Task 4: Perform signed native-menu visual and interaction acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-native-menu-refresh-row.md`

**Interfaces:**
- Consumes: the signed `.app` and Task 1 acceptance matrix.
- Produces: direct evidence that text correctness and native-menu interaction both pass.

- [x] **Step 1: Build the signed application**

Run `zsh CodexUsageMonitor/Scripts/build-app.sh`, verify the signature, and launch only the audit-owned instance through normal UI paths.

The signed bundle built successfully, passed strict signature verification and plist linting, and launched as audit PID 50956 while pre-existing user-owned PID 29637 remained untouched. PID 50956 was closed after the audit; PID 29637 remained running.

- [x] **Step 2: Observe semantic transitions in the actual menu**

Keep the menu open across refresh start/completion when reproducible. Confirm `Refreshing…` becomes an absolute next-refresh time, cached/paused remains correctly labeled, and reopening always shows the current state.

Directly observed: the connected/confirmed menu displayed one readable `Last refresh: <time> · Next refresh: <time>` row, with no overlap and with Refresh, Settings, and Quit in their existing order. A scheduled refresh changed the menu-bar quota label and the process remained healthy. The short-lived Refreshing state and a natural cached/paused result were not captured and remain manual.

- [x] **Step 3: Stress placement and hit-testing during transitions**

Before, during, and after a refresh transition, move the pointer across every row; scroll beyond Quit in both directions; and verify the highlighted row matches the pointer. Confirm the menu's outer frame and row frames do not jump. Activate Refresh, Settings, notification recovery when present, and Quit from the row visibly selected.

Automation limitation: macOS allowed the audit status item to open normally but denied accessibility hierarchy/control while its native menu was tracking (`-1719`). A coordinate-based fallback was rejected as unsafe after it failed to target the item reliably. Pointer and scroll placement therefore require direct user interaction on the signed build.

User acceptance on 2026-07-17 completed that direct interaction gate: scrolling beyond the intended menu area no longer displaced the highlight above the pointer, and the refresh/menu update continued to work. This closes the originally reported coupled regression. Conditional commands that were not naturally present remain covered only by the limitations below.

- [x] **Step 4: Exercise the full visual matrix**

Inspect connected, disconnected, refreshing, confirmed/completed, cached/paused, notification-denied, missing quota, and long-copy states. Inspect Light and Dark appearance. Record any state that cannot be manufactured as an explicit manual limitation.

- [x] **Step 5: Soak and inspect failure evidence**

Repeat open/close and pointer/scroll interaction across multiple refresh cycles, then inspect new crash reports. A clean compile or one correct transition is insufficient.

The audit process survived repeated menu opens and more than one scheduled interval. No `CodexUsageMonitor` diagnostic report newer than the audit start was created. Pointer/scroll repetition remains part of Step 3 rather than being inferred from process survival.

---

### Task 5: Gate any future true live countdown behind an architecture decision

**Files:**
- Create only after explicit approval: `docs/adr/0003-own-native-menu-for-live-status.md`
- Create only after explicit approval: `docs/superpowers/plans/2026-07-14-appkit-live-menu-countdown.md`

**Interfaces:**
- Consumes: a confirmed product requirement for per-second countdown animation.
- Produces: an explicit choice between the stable absolute-time native menu, an AppKit-owned fixed-geometry menu row, or a window-style popover.

- [ ] **Step 1: Do not expand the minimal fix implicitly**

If absolute next-refresh time satisfies the product need, stop after Task 4. Do not migrate away from `MenuBarExtra` pre-emptively.

- [ ] **Step 2: Evaluate the real alternatives if seconds must tick**

Compare:

- AppKit-owned `NSStatusItem`/`NSMenu` with a noninteractive, fixed-size timing row updated in place;
- `.menuBarExtraStyle(.window)` with normal SwiftUI invalidation but panel-style interaction;
- retaining the native `MenuBarExtra` without a live relative countdown.

Reject a design that depends on unsupported access to SwiftUI's private `NSMenu`, changes command semantics without approval, or lacks a stable accessibility path.

- [ ] **Step 3: Require a separate ADR and visual prototype**

The ADR must record why true per-second animation outweighs the additional AppKit ownership or popover behavior. The prototype must demonstrate fixed geometry, correct VoiceOver output, keyboard navigation, Light/Dark rendering, refresh transitions, and the below-Quit regression test before production migration begins.

Planning note (2026-07-17): the failed designs were not merely stale copy: per-second SwiftUI invalidation let the visible native menu and AppKit's tracked interaction geometry diverge, while an earlier timer-driven design recursively invalidated menu updates and crashed. Repository-level prevention now lives in [the native-menu dynamic-update guardrails](../../../AGENTS.md#native-menu-dynamic-update-guardrails). A future countdown must own a safe ticking surface and prove row stability; restoring a timer to the current SwiftUI menu tree is not an acceptable experiment.

---

### Task 6: Reconcile behavior and operating documentation

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-adaptive-refresh.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `UsageProbe/README.md`
- Modify: `how-to.md`
- Modify: `outline.md`

**Interfaces:**
- Consumes: the behavior and signed-app evidence accepted in Tasks 3–4.
- Produces: documentation that never calls a static relative value a live countdown.

- [x] **Step 1: Record the final timing language**

State whether the native menu shows an absolute next-refresh time or an explicitly approved live countdown. Remove superseded snapshot language and retain the coupled regression history.

- [x] **Step 2: Record exact visual evidence and limitations**

List the signed build, appearances, states, transitions, interaction paths, soak duration, and crash-report result. Do not mark unobserved conditional states complete.

`UsageProbe/README.md`, `how-to.md`, the adaptive-refresh plan, daily-driver roadmap, and `outline.md` now describe event-driven absolute next-refresh timing and retain the coupled highlight/crash history. This plan records the signed connected/scheduled visual pass, process/signature evidence, current-appearance-only coverage, and the blocked interaction/conditional-state matrix without marking those states complete.

## Verification evidence — 2026-07-17

- Fresh final existing suite: 5 tests, 0 failures. No test cases were added.
- Fresh warnings-as-errors implementation build: `Build complete! (1.78s)`.
- Fresh signed app build: `Build complete! (1.67s)` and ad-hoc signing completed.
- `codesign --verify --deep --strict --verbose=2`: valid on disk and satisfies its Designated Requirement.
- `plutil -lint`: `Info.plist: OK`.
- Direct signed `MenuBarExtra` inspection: connected/confirmed layout, absolute scheduled time, native inline commands, and no visible overlap passed in the current appearance.
- Source audit: no application/test reference remains to the countdown clock, child countdown view, one-second menu timer, `TimelineView`, or timer-interval `Text`.
- Soak/crash audit: audit PID 50956 survived repeated opens and scheduled refreshes; no new diagnostic report appeared.
- User-completed interaction acceptance: pointer/scroll placement on the original below-menu failure path passed while the refresh/menu update continued to work.
- Manual limitations: short-lived Refreshing capture, cached/paused, disconnected, denied notifications, missing-quota conditional content beyond the naturally absent five-hour lane, long localization, and the other appearance were not directly completed in this repair audit.

## Self-review

- Spec coverage: the plan protects semantic freshness, placement, hit-testing, activation, accessibility, and crash safety as one acceptance boundary.
- Scope control: the recommended repair does not migrate the entire menu or change refresh scheduling; live ticking is a separately approved architecture decision.
- Failure-mode coverage: the plan separates the working live countdown from the returned below-Quit/highlight regression and retains the earlier frozen-text and recursive-invalidation history.
- Evidence quality: source/history tracing supports diagnosis, while only the signed `MenuBarExtra` and direct user interaction supply final acceptance. No test cases are added by explicit user direction.
