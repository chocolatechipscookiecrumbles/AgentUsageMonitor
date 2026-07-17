# Distinct Menu Bar Connection and Cache Markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distinguish a disconnected Codex account from connected but cached quota data in the menu bar, so one pause-like icon never represents both.

**Architecture:** `MenuBarLabelPresentation` remains the pure state-to-view model. `MenuBarStatusLabel` supplies the live `AgentConnectionState`; explicit `.disconnected` takes precedence over cached quota presentation. Settings previews omit that optional input and continue previewing freshness only.

**Tech Stack:** Swift 6.2, SwiftUI `MenuBarExtra`, SF Symbols, existing connection/quota state, XCTest, signed-app build script.

**Status:** **Deferred.** Do not begin implementation without explicit user direction. The plan preserves the reported ambiguity and bounded implementation path; it is not part of the merged external-login fix.

## Global Constraints

- `.disconnected` uses `person.crop.circle.badge.xmark`; it means the account is not connected, not that the network is unavailable.
- Connected cached/paused data uses `clock.arrow.circlepath`; confirmed data has no extra marker. Remove the existing `pause.fill` marker.
- Do not add polling, a timer, a scheduler, a connection check, login/authentication behavior, a dependency, permission, persistence, menu row, or network inference.
- Do not reinterpret `.checking`, `.signingIn`, `.missingCLI`, or `.failed` as disconnected. Their existing menu-stage copy remains authoritative.
- Preserve text, gauge/dual display modes, width envelope, semantic colors, and Settings previews. Publish only semantic marker transitions.
- Keep one accessibility element: hide the child icon and include either “Codex is not connected” or “cached quota values” in the combined label.
- Add exactly one focused regression test; final acceptance is signed native-menu inspection in Light and Dark, with keyboard, pointer, and VoiceOver checks.

---

## File structure

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift`: define marker identity and precedence.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelView.swift`: render the presentation-owned marker.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift`: pass live connection state only at the real menu-bar boundary.
- Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuBarLabelPresentationTests.swift`: cover the reported ambiguity.
- Modify `docs/product/planning-board.md`, `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`, `how-to.md`, and `UsageProbe/README.md` after acceptance.

## Task 1: Add one unambiguous marker contract

**Files:**
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuBarLabelPresentationTests.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift`

**Interfaces:**
- Consumes: `QuotaDisplayState`, optional `AgentConnectionState`, `MenuBarDisplayStyle`, and `QuotaValueMode`.
- Produces: `MenuBarStatusMarker?` as `MenuBarLabelPresentation.statusMarker`; the initializer gains `connectionState: AgentConnectionState? = nil`.

- [ ] **Step 1: Write the focused failing regression test.**

~~~swift
import XCTest
@testable import CodexUsageMonitor

final class MenuBarLabelPresentationTests: XCTestCase {
    func test_disconnectedMarkerOverridesCachedQuotaMarker() {
        let cached = QuotaDisplayState(
            mode: .cachedPaused,
            displayedRecord: nil,
            lastAttemptAt: .distantPast,
            lastConfirmedAt: nil,
            pauseReason: .unavailable
        )
        let disconnected = MenuBarLabelPresentation(
            displayState: cached,
            style: .gaugeAndLowest,
            valueMode: .remaining,
            connectionState: .disconnected
        )
        let connected = MenuBarLabelPresentation(
            displayState: cached,
            style: .gaugeAndLowest,
            valueMode: .remaining,
            connectionState: .connected(AgentAccountSummary(planType: nil))
        )

        XCTAssertEqual(disconnected.statusMarker, .disconnected)
        XCTAssertEqual(disconnected.statusMarker?.systemImage, "person.crop.circle.badge.xmark")
        XCTAssertTrue(disconnected.accessibilityLabel.contains("Codex is not connected"))
        XCTAssertEqual(connected.statusMarker, .cached)
        XCTAssertEqual(connected.statusMarker?.systemImage, "clock.arrow.circlepath")
    }
}
~~~

- [ ] **Step 2: Run the test before implementation.**

Run:

~~~bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter MenuBarLabelPresentationTests/test_disconnectedMarkerOverridesCachedQuotaMarker
~~~

Expected: compilation fails because the initializer has neither `connectionState` nor `statusMarker`.

- [ ] **Step 3: Implement marker identity and precedence.**

Add the following next to `MenuBarLabelPresentation`:

~~~swift
enum MenuBarStatusMarker: Equatable, Sendable {
    case disconnected
    case cached

    var systemImage: String {
        switch self {
        case .disconnected: "person.crop.circle.badge.xmark"
        case .cached: "clock.arrow.circlepath"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .disconnected: "Codex is not connected"
        case .cached: "cached quota values"
        }
    }
}
~~~

Replace `showsPauseMarker` with `let statusMarker: MenuBarStatusMarker?`. Extend the initializer with `connectionState: AgentConnectionState? = nil`, and calculate it before building the accessibility label:

~~~swift
let statusMarker: MenuBarStatusMarker?
if case .disconnected = connectionState {
    statusMarker = .disconnected
} else if displayState.mode == .cachedPaused {
    statusMarker = .cached
} else {
    statusMarker = nil
}
self.statusMarker = statusMarker
let statusDescription = statusMarker?.accessibilityDescription ?? freshness
~~~

Keep the existing text calculations; replace each final freshness suffix with `statusDescription`. No monitor, connection-controller, or persistence file changes.

- [ ] **Step 4: Render the marker at the existing status-label boundary.**

In `MenuBarLabelView`, replace the pause-specific image with:

~~~swift
if let statusMarker = presentation.statusMarker {
    Image(systemName: statusMarker.systemImage)
        .imageScale(.small)
        .accessibilityHidden(true)
}
~~~

In `MenuBarStatusLabel`, add the real state to the existing initializer call:

~~~swift
connectionState: viewModel.connectionState
~~~

Leave all General Settings preview calls unchanged; the default `nil` deliberately prevents a preview from claiming live account status.

- [ ] **Step 5: Run the focused regression test.**

Run the Step 2 command again. Expected: PASS; the same cached display has the account-not-connected icon when disconnected and the cache icon when connected.

- [ ] **Step 6: Commit the behavioral slice.**

~~~bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelView.swift CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarStatusLabel.swift CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuBarLabelPresentationTests.swift
git commit -m "Differentiate menu bar connection status"
~~~

## Task 2: Perform signed native-menu acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-distinct-menu-bar-status-markers.md`

**Interfaces:**
- Consumes: the signed app, a fresh isolated disconnected `CODEX_HOME`, any naturally available connected cached state, and the native macOS menu bar.
- Produces: direct visual/accessibility evidence without touching the user's normal Codex home or manufacturing quota failures.

- [ ] **Step 1: Build and validate the signed app.**

Run:

~~~bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
~~~

Expected: the app builds, its signature verifies, and `Info.plist` reports `OK`.

- [ ] **Step 2: Inspect disconnected versus cached status.**

Launch only the signed app with a fresh isolated `CODEX_HOME`, without selecting either in-app sign-in action. Confirm its menu bar uses `person.crop.circle.badge.xmark`, never `pause.fill`, while its body remains the current disconnected stage. With a naturally available connected cached state, confirm `clock.arrow.circlepath`; with confirmed data, confirm no marker. Record unavailable states as **Not run**; do not alter cache files or force failures.

- [ ] **Step 3: Check interaction, appearance, and VoiceOver.**

Keep the menu open across every safely observable semantic transition, point across every row, scroll above and below the command area, and activate the visibly highlighted command. Inspect Light and Dark, keyboard, and VoiceOver navigation. Record unmanufactured states rather than inferring them.

- [ ] **Step 4: Record evidence and commit it.**

Record exact observed symbols, unrun states, and audit-process ownership; never record account identity, quota values, tokens, raw provider responses, or cache contents.

~~~bash
git add docs/superpowers/plans/2026-07-17-distinct-menu-bar-status-markers.md
git commit -m "Record menu bar status marker acceptance"
~~~

## Task 3: Synchronize planning and operating docs

**Files:**
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: accepted marker behavior and Task 2 evidence.
- Produces: truthful board status and user documentation that distinguishes cache freshness from account connection.

- [ ] **Step 1: Change the board item from Queued to Closed only after Task 2 passes.** Keep the new plan linked; do not alter the eight numbered product-follow-up rows.
- [ ] **Step 2: State in operating docs that disconnected uses the account-not-connected marker, connected cached quota uses the cache marker, confirmed quota has none, and neither marker diagnoses network availability or starts refreshes.**
- [ ] **Step 3: Run final verification.**

~~~bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
git diff --check
~~~

Expected: focused and existing tests pass, signed app builds, and no whitespace errors are reported.

- [ ] **Step 4: Commit synchronized docs.**

~~~bash
git add docs/product/planning-board.md docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md docs/superpowers/plans/2026-07-17-distinct-menu-bar-status-markers.md how-to.md UsageProbe/README.md
git commit -m "Document menu bar status markers"
~~~

## Plan self-review

- **Spec coverage:** Task 1 creates the two semantic markers and proves the reported ambiguity; Task 2 validates the signed native menu; Task 3 preserves a single product status model.
- **Scope control:** No collection, cache, connection, login, scheduler, menu structure, timer, network inference, or provider behavior changes.
- **Regression coverage:** One deterministic test asserts that disconnected overrides the identical cached display marker; manual acceptance covers native-menu behavior.
- **Type consistency:** `QuotaViewModel.connectionState` already publishes `AgentConnectionState`; only `MenuBarStatusLabel` forwards it. Previews retain the default `nil` state.


