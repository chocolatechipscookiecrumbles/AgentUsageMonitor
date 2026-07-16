# Native Menu Refresh Row Implementation Plan

> **Recovered status (2026-07-16): Pending and not started.** Restored from `wip/figma-followups-2026-07-15`; revalidate the proposed interfaces against current `main` before implementation, and follow the current repository `AGENTS.md` and evidence-rich PR guidance where this historical plan differs.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Do not treat an isolated SwiftUI host as final UI evidence; every accepted rendering change requires the signed app's actual `MenuBarExtra`.

**Goal:** Make the native menu's refresh-timing row semantically current without reviving stale highlighting, incorrect hit-testing, recursive invalidation, or crashes.

**Architecture:** Keep `QuotaMonitor` and `QuotaViewModel` as the scheduling and UI-state owners, but replace the independently observed countdown child with one immutable, event-driven `MenuRefreshTimingPresentation` consumed by the already-observed menu root. Preserve the native menu's structure and show an absolute next-refresh time rather than a relative value that appears to count down while frozen. If a true per-second countdown remains a product requirement, evaluate it later as an explicit AppKit-owned fixed-geometry menu architecture, not as a one-line observation rollback.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, AppKit, macOS 14+; native `MenuBarExtra` for the recommended repair and a signed `.app` for final visual acceptance.

## Global Constraints

- Preserve the existing native pull-down menu, inline commands, ordering, visual language, and compact footprint for the recommended repair.
- Do not restore `@ObservedObject` on `NextRefreshCountdownView`, `TimelineView`, timer-interval `Text`, or per-second root invalidation as the production fix.
- Keep row count, row identity, control type, and geometry stable while the menu is tracking.
- Refresh-start, refresh-completion, cached/paused, and next-schedule changes are correctness transitions and must update; per-second elapsed-time animation is secondary.
- Do not modify collection cadence, refresh scheduling, quota trust semantics, notification behavior, or Settings behavior.
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

- [ ] **Step 1: Record the state and observation path**

Document the exact chain `QuotaMonitor publishers -> QuotaViewModel sinks -> countdownClock.update(...) -> RefreshCountdownClock.$text -> NextRefreshCountdownView -> MenuBarExtra`. Mark the current break explicitly: the clock changes, but `let clock` creates no SwiftUI invalidation boundary.

- [ ] **Step 2: Reproduce both historical failure modes**

Use the signed app to record the current frozen `Refreshing…`/countdown behavior. Retain the July 14 evidence for the former observed implementation: scrolling or pointing below Quit highlighted earlier value rows. Do not reintroduce the old code merely to reproduce it in the user's running app.

- [ ] **Step 3: Create the acceptance matrix before implementation**

Record expected behavior for refreshing, refresh completion, scheduled, deadline reached, confirmed/completed, cached/paused, disconnected, denied notifications, missing quota lanes, and long localized strings. For each state, include displayed text, row count/order, enabled commands, and expected transition.

- [ ] **Step 4: Stop for a pre-code review checkpoint**

Review the state path, both historical regressions, the acceptance matrix, and the proposed absolute-time behavior before modifying production Swift. Do not proceed merely because the one-line `@ObservedObject` rollback passes an isolated rendering harness.

---

### Task 2: Replace the ticking child with an event-driven presentation contract

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuRefreshTimingPresentation.swift`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuRefreshTimingPresentationTests.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState.lastAttemptAt`, `RefreshState`, and `QuotaMonitor.nextRefreshAt`.
- Produces: `MenuRefreshTimingPresentation` and `QuotaViewModel.refreshTimingPresentation`.

- [ ] **Step 1: Define one immutable semantic value**

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

- [ ] **Step 2: Write focused transition tests**

Cover idle-to-refreshing, refreshing-to-scheduled, scheduled-time replacement, cached/paused completion, and no-next-date scheduling. Assert value transitions rather than localized strings or timer behavior.

For example, the refresh-completion case must prove that the same row value leaves its semantic refreshing phase:

```swift
final class MenuRefreshTimingPresentationTests: XCTestCase {
    func test_refreshCompletionBecomesScheduled() {
        let lastRefresh = Date(timeIntervalSince1970: 1_000)
        let nextRefresh = Date(timeIntervalSince1970: 1_120)

        let refreshing = MenuRefreshTimingPresentation(
            lastRefreshAt: lastRefresh,
            refreshState: .refreshing(reason: .manual),
            nextRefreshAt: nil
        )
        let completed = MenuRefreshTimingPresentation(
            lastRefreshAt: lastRefresh,
            refreshState: .idle,
            nextRefreshAt: nextRefresh
        )

        XCTAssertEqual(refreshing.phase, .refreshing)
        XCTAssertEqual(completed.phase, .scheduled(nextRefreshAt: nextRefresh))
    }
}
```

- [ ] **Step 3: Publish from the existing view-model boundary**

Add `@Published private(set) var refreshTimingPresentation` to `QuotaViewModel`. Recompute it after the relevant monitor sinks update, ensuring one coherent final value per semantic transition. Do not publish once per elapsed second.

- [ ] **Step 4: Verify the domain slice**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter MenuRefreshTimingPresentationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path CodexUsageMonitor -Xswiftc -warnings-as-errors
```

Expected: the focused tests pass and the build ends with `Build complete!`. Passing here proves state coherence only; it does not satisfy native-menu visual acceptance.

---

### Task 3: Render truthful, fixed-geometry native-menu copy

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift`
- Replace or remove: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NextRefreshCountdownView.swift`
- Remove if unused: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/RefreshCountdownClock.swift`

**Interfaces:**
- Consumes: `QuotaViewModel.refreshTimingPresentation` through the existing `@ObservedObject` root.
- Produces: one stable plain-text native-menu row.

- [ ] **Step 1: Keep one row in every connected timing phase**

Render one `Text` at the same position for refreshing, scheduled, and scheduling. Do not conditionally insert a replacement view, change the row into a button, or attach a child-level observable object.

- [ ] **Step 2: Use copy that matches its update semantics**

Render:

- `Last refresh: 23:31 · Refreshing…`
- `Last refresh: 23:31 · Next refresh: 23:33`
- `Last refresh: 23:31 · Scheduling…`

The scheduled form uses an absolute time because it remains truthful without per-second invalidation. Do not display `Next: 1:42` unless it actually advances while open.

- [ ] **Step 3: Preserve accessibility and width behavior**

Keep the row a single accessibility element with semantic text and disable implicit animation for its semantic replacement. Inspect the longest supported time representation and verify the menu's outer frame and every row frame remain stable during a semantic transition. If the timing row controls menu width, reserve one constant layout envelope for all three phase strings rather than allowing the tracked menu to resize.

- [ ] **Step 4: Remove obsolete ticking ownership only after reference inspection**

Use `rg` to confirm `RefreshCountdownClock` and `NextRefreshCountdownView` have no remaining consumers before removal. This task must not alter `QuotaMonitor`'s one-shot refresh scheduler.

---

### Task 4: Perform signed native-menu visual and interaction acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-native-menu-refresh-row.md`

**Interfaces:**
- Consumes: the signed `.app` and Task 1 acceptance matrix.
- Produces: direct evidence that text correctness and native-menu interaction both pass.

- [ ] **Step 1: Build the signed application**

Run `zsh CodexUsageMonitor/Scripts/build-app.sh`, verify the signature, and launch only the audit-owned instance through normal UI paths.

- [ ] **Step 2: Observe semantic transitions in the actual menu**

Keep the menu open across refresh start/completion when reproducible. Confirm `Refreshing…` becomes an absolute next-refresh time, cached/paused remains correctly labeled, and reopening always shows the current state.

- [ ] **Step 3: Stress placement and hit-testing during transitions**

Before, during, and after a refresh transition, move the pointer across every row; scroll beyond Quit in both directions; and verify the highlighted row matches the pointer. Confirm the menu's outer frame and row frames do not jump. Activate Refresh, Settings, notification recovery when present, and Quit from the row visibly selected.

- [ ] **Step 4: Exercise the full visual matrix**

Inspect connected, disconnected, refreshing, confirmed/completed, cached/paused, notification-denied, missing quota, and long-copy states. Inspect Light and Dark appearance. Record any state that cannot be manufactured as an explicit manual limitation.

- [ ] **Step 5: Soak and inspect failure evidence**

Repeat open/close and pointer/scroll interaction across multiple refresh cycles, then inspect new crash reports. A clean compile or one correct transition is insufficient.

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

- [ ] **Step 1: Record the final timing language**

State whether the native menu shows an absolute next-refresh time or an explicitly approved live countdown. Remove superseded snapshot language and retain the coupled regression history.

- [ ] **Step 2: Record exact visual evidence and limitations**

List the signed build, appearances, states, transitions, interaction paths, soak duration, and crash-report result. Do not mark unobserved conditional states complete.

## Self-review

- Spec coverage: the plan protects semantic freshness, placement, hit-testing, activation, accessibility, and crash safety as one acceptance boundary.
- Scope control: the recommended repair does not migrate the entire menu or change refresh scheduling; live ticking is a separately approved architecture decision.
- Failure-mode coverage: the plan tests the original frozen-text regression and the earlier below-Quit/recursive-invalidation regressions.
- Evidence quality: isolated hosts and unit tests support diagnosis, while only the signed `MenuBarExtra` supplies final acceptance.
