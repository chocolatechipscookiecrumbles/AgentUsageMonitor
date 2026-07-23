# Menu Bar Popover Review Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the multi-provider popover review findings, keep the popover compact without introducing scrolling, and leave signed-app visual acceptance explicitly open for a later pass.

**Architecture:** `ClaudeUsageMonitor` becomes the single refresh-serialization owner, while `QuotaViewModel` remains a shallow UI adapter. Provider-summary mapping excludes expired Claude windows before selecting the menu-bar value. The popover stays an intrinsic-height, non-scrolling window by bounding variable-length popover-only content; Settings continues to expose complete data.

**Tech Stack:** Swift 6.2, SwiftUI for macOS 14+, Combine, XCTest, Swift Package Manager.

**Execution status (2026-07-24):** Source-only Tasks 1–5 are complete. Tasks 1–4 are implemented in commits `f15f039`, `bc51c51`, `5be8815`, and `12c5ada`; focused regressions pass, the full suite passes 233 tests with zero failures, and the source build succeeds. The signed-app gate and Deferred Tasks 6–7 remain unexecuted.

## Global Constraints

- Work only on `feature/multiprovider-menubar-popover`; preserve unrelated user changes.
- Opening the popover must remain passive: no refresh, timer, `TimelineView`, or per-second invalidation.
- Do not add a `ScrollView`, `List`, or hidden clipped region to `MenuBarPopoverView`.
- Keep the popover width at `340` points and retain Codex/Claude tabs, fixed header, and fixed footer.
- Bound variable-length popover-only content: show at most two reset-credit expiry rows and at most three lines of recovery or unavailable detail.
- Keep the complete reset-credit expiry list and full diagnostic/recovery detail available in Settings.
- `Refresh Now` stays inside the open popover and publishes the active provider’s in-place `Refreshing…` state.
- Escape must dismiss the production popover, not only the viability-gate placeholder.
- Preserve the regression-only test policy: add automated coverage only for expired-window selection, cross-reason refresh overlap, and the unbounded expiry mapping identified in review.
- Verification for this pass is `swift test --disable-sandbox`, `swift build --disable-sandbox`, and `git diff --check`.
- Do not run `Scripts/build-app.sh`, launch the `.app`, or claim signed-app, Light/Dark, keyboard, VoiceOver, or visual acceptance in this pass.
- Update this plan and the existing verification guide with the exact unobserved signed-app boundary.
- Do not attempt a provider-switching or corner-artifact repair in this pass. Both require a later signed-app reproduction and prototype comparison before production changes.
- Do not use `.id(selection)`, disabled-animation transactions, delayed selection writes, or window recreation as provider-switching workarounds; prior Settings experiments already rejected those approaches.

---

## File Map

### Provider-summary correctness

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderSummary.swift` — exclude expired Claude windows and accept an injectable reference date.
- Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuProviderSummaryTests.swift` — protect expired-window exclusion and active-window selection.

### Refresh ownership

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift` — serialize all launch, scheduled, and user-initiated reads and publish one refresh flag.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — observe the monitor’s refresh flag; remove its competing manual-task owner and the unused menu-open refresh entry point.
- Modify `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift` — reproduce and protect cross-reason refresh coalescing.

### Production interaction

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift` — keep Refresh Now open and handle Escape in the shipping view.
- Modify `docs/design/menu-bar-popover/SPEC.md` — mark the keep-open behavior implemented while leaving GUI observation open.

### Non-scrolling content budget

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverTheme.swift` — own the two-row and three-line content bounds.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuPresentation.swift` — derive a bounded expiry presentation without changing stored quota data.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexCreditsCard.swift` — render only bounded expiry rows plus a Settings continuation caption.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexUnavailableContent.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeUnavailableContent.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexConnectionRecoveryCard.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/NotificationPermissionStrip.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexUsageWindowRow.swift`
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeUsageWindowRow.swift`
- Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexMenuPresentationTests.swift` — protect the reproduced unbounded-expiry regression with a deterministic presentation test.

### Documentation and handoff

- Modify `docs/claude-usage-verification.md`
- Modify `docs/product/planning-board.md`
- Modify `docs/superpowers/plans/2026-07-22-menu-bar-popover-figma-port.md`
- Modify `docs/superpowers/plans/2026-07-23-menu-bar-popover-refinements.md`
- Modify `how-to.md`
- Modify `UsageProbe/README.md`

---

## Source-only comparison: Settings Agents tabs versus menu-bar tabs

The two surfaces do **not** use the same tab component:

| Concern | Settings Agents page | Menu-bar popover |
|---|---|---|
| Tab view | `AgentSettingsTabStrip` | `MenuProviderTabStrip` |
| Layout | `ViewThatFits`, fixed-width icon tabs, horizontal-scroll fallback | Equal-width text buttons in a fixed 340-point strip |
| Selection owner | `SettingsView.selectedSettingsAgent` | `MenuBarPopoverView.selectedProvider` |
| Persistence | Session-only `@State` | Persisted through `AppSettings.selectedMenuProvider` |
| Content host | `SettingsDetailView` → `AgentsSettingsView` → `AgentSettingsPageTemplate` | `MenuBarPopoverView.providerContent` |
| Outer geometry | Fixed Settings Page frame | Intrinsic-height `MenuBarExtra(.window)` |

They nevertheless share a relevant structural pattern:

1. A custom plain SwiftUI `Button` writes an `AgentProvider` binding.
2. An enum `switch` replaces the provider-specific child subtree.
3. Both provider subtrees consume the shared, frequently publishing `QuotaViewModel`.

This source similarity is enough to justify one coordinated investigation, but not enough to claim one root cause. The previously recorded Settings destination-switch compositor defect concerns the global General/Notifications/etc. switch, not specifically the nested Agents selector. Its rejected `.id` and disabled-animation workarounds must not be copied into either provider-tab surface.

The user-reported symptoms to preserve verbatim as the later diagnostic target are:

- after switching provider tabs, page items jump or move before settling, as if the page refreshed;
- sometimes a provider-tab button does not respond for a short period;
- sometimes the selection appears stuck;
- the behavior is visible in both the Settings Agents selector and menu-bar provider selector.

No red-capable automated or signed-app reproduction was run during this source-only planning pass, so no provider-switching cause or fix is claimed.

---

### Task 1: Exclude expired Claude windows from the menu-bar summary

**Status:** Completed in `f15f039`; both deterministic regressions pass.

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderSummary.swift:67-79`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuProviderSummaryTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageState`, `ClaudeUsageDisplayModel.Window.hasReset`
- Produces: `MenuProviderSummary.claude(usageState:now:) -> MenuProviderSummary`

- [ ] **Step 1: Add deterministic regression coverage**

Create `MenuProviderSummaryTests.swift` with a fixed reference date and these two cases:

```swift
import XCTest
@testable import CodexUsageMonitor

final class MenuProviderSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testClaudeSummaryIgnoresExpiredWindowWhenAnActiveWindowExists() {
        let state = makeState(
            fiveHour: ClaudeLimitWindow(
                usedPercent: 92,
                resetsAt: now.addingTimeInterval(-60)
            ),
            sevenDay: ClaudeLimitWindow(
                usedPercent: 37,
                resetsAt: now.addingTimeInterval(3_600)
            )
        )

        let summary = MenuProviderSummary.claude(usageState: state, now: now)

        XCTAssertEqual(summary.usedPercent, 37)
    }

    func testClaudeSummaryIsUnavailableWhenEveryWindowHasExpired() {
        let state = makeState(
            fiveHour: ClaudeLimitWindow(
                usedPercent: 92,
                resetsAt: now.addingTimeInterval(-60)
            ),
            sevenDay: ClaudeLimitWindow(
                usedPercent: 81,
                resetsAt: now.addingTimeInterval(-120)
            )
        )

        let summary = MenuProviderSummary.claude(usageState: state, now: now)

        XCTAssertNil(summary.usedPercent)
        XCTAssertNil(summary.freshness)
    }

    private func makeState(
        fiveHour: ClaudeLimitWindow?,
        sevenDay: ClaudeLimitWindow?
    ) -> ClaudeUsageState {
        .available(
            ClaudeUsagePresentation(
                snapshot: ClaudeUsageSnapshot(
                    planHint: "pro",
                    fiveHour: fiveHour,
                    sevenDay: sevenDay,
                    scopedWindows: [],
                    extraUsage: nil,
                    source: .oauth,
                    capturedAt: now,
                    schemaVersion: 1
                ),
                delivery: .live,
                warnings: []
            )
        )
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm the old behavior fails**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter MenuProviderSummaryTests
```

Expected before implementation: both tests fail because expired window percentages still participate in `highestUtilization`.

- [ ] **Step 3: Filter expired windows in the presentation mapper**

Change the Claude factory to inject `now` and filter each mapped window:

```swift
static func claude(
    usageState: ClaudeUsageState,
    now: Date = .now
) -> Self {
    guard let presentation = usageState.presentation else {
        return Self(provider: .claudeCode, usedPercent: nil, freshness: nil)
    }
    let model = ClaudeUsageDisplayModel(presentation: presentation, now: now)
    return Self(
        provider: .claudeCode,
        usedPercent: highestUtilization(
            eligibleUsedPercent(model.fiveHour),
            eligibleUsedPercent(model.sevenDay)
        ),
        freshness: freshness(for: presentation.delivery)
    )
}

private static func eligibleUsedPercent(
    _ window: ClaudeUsageDisplayModel.Window?
) -> Int? {
    guard let window, !window.hasReset else { return nil }
    return window.usedPercent
}
```

The existing `MenuBarStatusLabel` call keeps using the default `now`.

- [ ] **Step 4: Run the focused test and full suite**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter MenuProviderSummaryTests
swift test --disable-sandbox
```

Expected: two focused tests pass; the full suite reports zero failures.

- [ ] **Step 5: Commit the correction**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderSummary.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuProviderSummaryTests.swift
git commit -m "Ignore expired Claude windows in menu summary"
```

---

### Task 2: Make `ClaudeUsageMonitor` the single refresh owner

**Status:** Completed in `bc51c51`; all nine `ClaudeUsageMonitorTests` pass.

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift:19-70`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift:19-35,101-124,175-193`
- Modify: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift`

**Interfaces:**
- Consumes: `ClaudeUsageCollecting.refresh(reason:)`
- Produces: `ClaudeUsageMonitor.isRefreshing: Bool`
- Preserves: `ClaudeUsageMonitor.refreshNow(reason:) async`

- [ ] **Step 1: Add a blocking collector to reproduce overlap**

Append this actor to `ClaudeUsageMonitorTests.swift`:

```swift
private actor BlockingCollector: ClaudeUsageCollecting {
    private let result: ClaudeUsagePresentation
    private var reasons: [ClaudeRefreshReason] = []
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ result: ClaudeUsagePresentation) {
        self.result = result
    }

    func refresh(reason: ClaudeRefreshReason) async -> ClaudeUsagePresentation {
        reasons.append(reason)
        if reasons.count > 1 {
            return result
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return result
    }

    func seenReasons() -> [ClaudeRefreshReason] {
        reasons
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
```

Add the regression:

```swift
func testConcurrentRefreshReasonsShareOneInFlightRead() async {
    let collector = BlockingCollector(presentation(delivery: .live))
    let monitor = ClaudeUsageMonitor(collector: collector)

    let scheduled = Task {
        await monitor.refreshNow(reason: .scheduled)
    }
    for _ in 0..<500 {
        if !(await collector.seenReasons()).isEmpty {
            break
        }
        await Task.yield()
    }

    let manual = Task {
        await monitor.refreshNow(reason: .userInitiated)
    }
    await Task.yield()

    let reasonsWhileBlocked = await collector.seenReasons()
    XCTAssertEqual(reasonsWhileBlocked, [.scheduled])
    XCTAssertTrue(monitor.isRefreshing)

    await collector.release()
    await scheduled.value
    await manual.value

    XCTAssertFalse(monitor.isRefreshing)
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter ClaudeUsageMonitorTests/testConcurrentRefreshReasonsShareOneInFlightRead
```

Expected before implementation: two reasons reach the collector, or no monitor-owned `isRefreshing` property exists.

- [ ] **Step 3: Serialize every refresh inside `ClaudeUsageMonitor`**

Add the published state:

```swift
@Published private(set) var isRefreshing = false
```

Replace `refreshNow(reason:)` with:

```swift
func refreshNow(reason: ClaudeRefreshReason) async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    let presentation = await collector.refresh(reason: reason)
    state = Self.mapState(presentation)
    hasCompletedInitialRefresh = true
}
```

Because `ClaudeUsageMonitor` is `@MainActor`, the flag remains the serialization gate across suspension and covers app launch, scheduled polling, connection recovery, and user actions.

- [ ] **Step 4: Remove the competing task owner from `QuotaViewModel`**

Delete:

```swift
@Published private(set) var isRefreshingClaude = false
private var claudeRefreshTask: Task<Void, Never>?
```

Replace them with a published adapter property and subscription:

```swift
@Published private(set) var isRefreshingClaude = false
```

```swift
claudeMonitor.$isRefreshing
    .removeDuplicates()
    .sink { [weak self] isRefreshing in
        self?.isRefreshingClaude = isRefreshing
    }
    .store(in: &subscriptions)
```

Replace `refreshClaude()` with:

```swift
func refreshClaude() {
    Task { [claudeMonitor] in
        await claudeMonitor.refreshNow(reason: .userInitiated)
    }
}
```

Delete the unused `refreshClaudeOnMenuOpen()` method entirely. No production caller exists, and retaining an entry point contradicts the passive-open contract.

- [ ] **Step 5: Run focused and full verification**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter ClaudeUsageMonitorTests
swift test --disable-sandbox
```

Expected: all `ClaudeUsageMonitorTests` pass; the full suite reports zero failures.

- [ ] **Step 6: Commit the ownership correction**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift
git commit -m "Serialize Claude usage refreshes"
```

---

### Task 3: Keep Refresh Now open and make Escape a production command

**Status:** Completed in `5be8815`; source build passes. Signed-app interaction remains unobserved.

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift:24-54,105-115`
- Modify: `docs/design/menu-bar-popover/SPEC.md`
- Modify: `docs/claude-usage-verification.md:476-478`

**Interfaces:**
- Consumes: SwiftUI `DismissAction`, `QuotaViewModel.refresh()`, `QuotaViewModel.refreshClaude()`
- Produces: production Escape dismissal and an in-place refresh state

- [ ] **Step 1: Remove dismissal from the refresh command**

Change:

```swift
private func refresh() {
    dismiss()
    switch activeProvider {
```

to:

```swift
private func refresh() {
    switch activeProvider {
```

Keep dismissal in Notification Settings, Preferences, and Quit.

- [ ] **Step 2: Handle Escape on the production popover root**

Attach the exit command to the chrome content:

```swift
MenuPopoverChrome {
    VStack(spacing: 0) {
        MenuProviderTabStrip(
            providers: MenuPopoverProviderCatalog.availableProviders,
            selection: $selectedProvider
        )

        MenuProviderHeader(
            provider: activeProvider,
            presentation: headerPresentation
        )

        providerContent

        MenuActionFooter(
            isRefreshing: isRefreshing,
            refresh: refresh,
            openNotificationSettings: showNotificationSettings,
            openPreferences: showPreferences,
            quit: quit
        )
    }
    .onChange(of: selectedProvider) { _, newValue in
        viewModel.settings.selectedMenuProvider =
            MenuPopoverProviderCatalog.resolvedSelection(newValue)
    }
    .onExitCommand {
        dismiss()
    }
}
```

Do not add a visible Close row or an extra footer action.

- [ ] **Step 3: Update the written contract**

In `SPEC.md`, replace “Implementation deferred” for keep-open refresh with:

```markdown
Implemented in source: Refresh Now remains open and the existing provider header/footer
reflect `Refreshing…`. Signed-app visual and keyboard observation remain open.
```

In `docs/claude-usage-verification.md`, state that Refresh Now no longer dismisses and add an unchecked production Escape step.

- [ ] **Step 4: Run source verification**

Run:

```bash
cd CodexUsageMonitor
swift build --disable-sandbox
swift test --disable-sandbox
cd ..
git diff --check
```

Expected: build succeeds, full suite reports zero failures, and `git diff --check` prints nothing.

- [ ] **Step 5: Commit the production interaction**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift \
  docs/design/menu-bar-popover/SPEC.md \
  docs/claude-usage-verification.md
git commit -m "Keep popover open during refresh"
```

---

### Task 4: Bound variable content without adding scrolling

**Status:** Completed in `12c5ada`; the bounded-expiry regression passes and the production provider roots contain no `ScrollView` or `List`.

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverTheme.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuPresentation.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexCreditsCard.swift`
- Modify the seven copy-bearing views listed in the File Map
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexMenuPresentationTests.swift`

**Interfaces:**
- Produces: `MenuPopoverTheme.maximumVisibleResetCreditExpiries`
- Produces: `MenuPopoverTheme.maximumDetailLines`
- Produces: `CodexMenuPresentation.Credits.visibleResetCreditExpiryDates`
- Produces: `CodexMenuPresentation.Credits.hiddenResetCreditExpiryCount`

- [ ] **Step 1: Add regression coverage for the unbounded expiry list**

Create `CodexMenuPresentationTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class CodexMenuPresentationTests: XCTestCase {
    func testCreditsBoundExpiryRowsAndReportTheHiddenCount() throws {
        let expiries = (1...5).map {
            Date(timeIntervalSince1970: 2_000_000_000 + Double($0 * 3_600))
        }
        let quota = QuotaPresentation(
            accountFingerprint: "test-account",
            limitID: "codex",
            planType: "pro",
            creditBalance: "12.34567",
            hasCredits: true,
            availableResetCredits: 5,
            resetCreditExpiryDates: expiries,
            fiveHour: QuotaWindow(usedPercent: 20, resetAt: nil, durationMinutes: 300),
            weekly: QuotaWindow(usedPercent: 30, resetAt: nil, durationMinutes: 10_080),
            confirmation: .confirmed,
            collectedAt: Date(timeIntervalSince1970: 2_000_000_000),
            source: "test",
            detail: nil
        )
        let state = QuotaDisplayState(
            mode: .confirmedCompleted,
            displayedRecord: .withoutForecasts(quota),
            lastAttemptAt: quota.collectedAt,
            lastConfirmedAt: quota.collectedAt,
            pauseReason: nil
        )

        let presentation = try XCTUnwrap(
            CodexMenuPresentation(
                displayState: state,
                fiveHourForecast: nil,
                weeklyForecast: nil
            )
        )
        let credits = try XCTUnwrap(presentation.credits)

        XCTAssertEqual(credits.visibleResetCreditExpiryDates, Array(expiries.prefix(2)))
        XCTAssertEqual(credits.hiddenResetCreditExpiryCount, 3)
    }
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter CodexMenuPresentationTests
```

Expected before implementation: the bounded expiry properties do not exist.

- [ ] **Step 3: Add shared popover bounds**

Add to `MenuPopoverTheme`:

```swift
static let maximumVisibleResetCreditExpiries = 2
static let maximumDetailLines = 3
static let maximumSupportingLines = 2
```

These are popover-only density tokens. Do not apply them to Settings.

- [ ] **Step 4: Bound the credit presentation**

Replace the expiry storage in `CodexMenuPresentation.Credits` with:

```swift
let visibleResetCreditExpiryDates: [Date]
let hiddenResetCreditExpiryCount: Int
```

Build it from the complete source list:

```swift
let sortedExpiries = presentation.resetCreditExpiryDates.sorted()
let visibleExpiries = Array(
    sortedExpiries.prefix(MenuPopoverTheme.maximumVisibleResetCreditExpiries)
)
credits = Credits(
    balance: Self.roundedBalance(presentation.creditBalance),
    availableResetCredits: presentation.availableResetCredits,
    visibleResetCreditExpiryDates: visibleExpiries,
    hiddenResetCreditExpiryCount: sortedExpiries.count - visibleExpiries.count
)
```

The original `QuotaPresentation.resetCreditExpiryDates` remains unchanged, so Settings retains the complete list.

- [ ] **Step 5: Render the bounded credit list**

In `CodexCreditsCard`, iterate `visibleResetCreditExpiryDates`. When `hiddenResetCreditExpiryCount > 0`, add:

```swift
Text("+\(credits.hiddenResetCreditExpiryCount) more in Settings")
    .font(.caption)
    .foregroundStyle(theme.secondaryText)
```

When the complete source list is empty, preserve “No earned reset-credit expiry is available.”

- [ ] **Step 6: Bound variable recovery and supporting copy**

Apply `.lineLimit(MenuPopoverTheme.maximumDetailLines)` and `.fixedSize(horizontal: false, vertical: true)` to the main detail text in:

- `CodexUnavailableContent`
- `ClaudeUnavailableContent`
- `CodexConnectionRecoveryCard`
- `ClaudeConnectionRecoveryCard`

Apply `.lineLimit(MenuPopoverTheme.maximumSupportingLines)` to:

- `NotificationPermissionStrip` explanation
- `CodexUsageWindowRow` forecast
- `ClaudeUsageWindowRow` weekly footnote
- `CodexCachedWarningStrip` text
- `ClaudeStalenessStrip` text

Do not truncate button labels, provider names, status-pill labels, percentages, or reset timing.

- [ ] **Step 7: Confirm the root stays non-scrolling**

Run:

```bash
rg -n "ScrollView|List\\(" \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift
```

Expected: no matches.

- [ ] **Step 8: Run focused and full verification**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox --filter CodexMenuPresentationTests
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
```

Expected: focused test passes, full suite reports zero failures, build succeeds, and `git diff --check` prints nothing.

- [ ] **Step 9: Commit the non-scrolling content budget**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Menu \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexMenuPresentationTests.swift
git commit -m "Bound popover content without scrolling"
```

---

### Task 5: Reconcile documentation and record the unsigned verification boundary

**Status:** Completed source-only. Documentation reflects the unobserved signed-app boundary; 233 tests and the source build pass. No signed app or GUI process was run.

**Files:**
- Modify the six documentation files listed in the File Map

**Interfaces:**
- Consumes: completed Tasks 1–4 and their command output
- Produces: a truthful handoff that separates source verification from signed-app acceptance

- [ ] **Step 1: Update the active Figma-port plan**

Append a “Review follow-ups” section to `2026-07-22-menu-bar-popover-figma-port.md` recording:

- expired Claude windows no longer drive the menu-bar summary;
- `ClaudeUsageMonitor` serializes every refresh reason;
- Refresh Now remains open;
- production Escape has a source handler;
- the popover has no scrolling and caps expiry/recovery detail;
- signed-app and GUI acceptance were not run in this pass.

- [ ] **Step 2: Close the implemented refinement and preserve the visual gate**

In `2026-07-23-menu-bar-popover-refinements.md`, mark the keep-open Refresh Now source task implemented. Retain corner, shadow, Light/Dark, keyboard, VoiceOver, and rendered-height checks as unobserved.

- [ ] **Step 3: Update user-facing behavior**

Update `how-to.md` and `UsageProbe/README.md` to state:

- Refresh Now keeps the popover open and shows progress;
- the popover intentionally does not scroll;
- at most two reset-credit expiry dates are shown there;
- complete expiry details remain in Settings.

- [ ] **Step 4: Update the verification guide**

In `docs/claude-usage-verification.md`, add unchecked signed-app cases for:

- an expired Claude five-hour window plus active weekly window;
- launch/scheduled refresh overlapping a manual click;
- Escape on the production popover;
- Refresh Now staying open through completion;
- the worst-height Codex state: cached warning, two forecasts, credits, disconnected recovery, and denied-notification strip;
- two visible expiry rows plus the “more in Settings” caption;
- Light and Dark appearance, keyboard focus, and VoiceOver.

Do not mark these cases passed.

- [ ] **Step 5: Update the planning board**

Keep the popover in **Verification**. Replace the old summary with:

```markdown
Source implementation and automated regression verification are complete. The popover
uses bounded intrinsic content with no scrolling. Signed-app rendered-height,
Light/Dark, keyboard, VoiceOver, and live-provider acceptance remain open.
```

- [ ] **Step 6: Run the allowed final verification**

Run:

```bash
cd CodexUsageMonitor
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
git status --short
```

Expected:

- full suite reports zero failures;
- build succeeds;
- `git diff --check` prints nothing;
- `git status --short` lists only the intended implementation and documentation files.

Do not run the signed-app build or launch a GUI process.

- [ ] **Step 7: Commit documentation and evidence**

```bash
git add docs/superpowers/plans/2026-07-22-menu-bar-popover-figma-port.md \
  docs/superpowers/plans/2026-07-23-menu-bar-popover-refinements.md \
  docs/superpowers/plans/2026-07-23-menu-bar-popover-review-followups.md \
  docs/design/menu-bar-popover/SPEC.md \
  docs/claude-usage-verification.md \
  docs/product/planning-board.md \
  how-to.md \
  UsageProbe/README.md
git commit -m "Document popover review follow-ups"
```

---

## Later Signed-App Acceptance Gate

This gate is intentionally outside the present execution pass. It must be completed before the branch is described as visually accepted or ready to merge:

1. Build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh`.
2. Launch only the audit-owned app instance through the normal menu-bar path.
3. Inspect the worst-height Codex combination and both Claude availability states without scrolling.
4. Verify no content or footer action is clipped on the smallest supported display.
5. Check Light and Dark appearance.
6. Verify Tab/Shift-Tab, Return/Space, Escape, and VoiceOver entry/escape.
7. Verify Refresh Now stays open, shows `Refreshing…`, disables duplicate refresh, and updates in place.
8. Record screenshots and observed results in `docs/claude-usage-verification.md` and the active implementation plan.
9. Close only the app process started for the audit; do not terminate a user-owned instance.

Until this gate is completed, planning-board status remains **Verification**.

---

## Deferred Task 6: Diagnose provider-tab jumping, delayed clicks, and stuck selection

**Status:** Explicitly deferred. Do not execute during Tasks 1–5. Resume only when signed-app launch and frame capture are authorized.

**Files to inspect or prototype later:**

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsTabStrip.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsHeader.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsPageTemplate.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderTabStrip.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverChrome.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- `docs/superpowers/plans/2026-07-18-settings-palette-and-refresh-preferences-presentation.md`
- `AGENTS.md`

### Required feedback loops

Build two separate red-capable loops; do not assume success on one surface proves the other:

1. **Settings Agents loop**
   - Open Settings → Agents with the Context Rail hidden.
   - Alternate Codex → Claude → Codex 20 times at a steady one-click-per-second cadence.
   - Repeat with the Context Rail visible.
   - Record whether each pointer-down produces a button action, selection write, provider subtree appearance, and settled frame.

2. **Menu-bar loop**
   - Open the production popover.
   - Alternate Codex → Claude → Codex 20 times without closing it.
   - Repeat while one provider is refreshing and again with cached/unavailable content.
   - Record button action, selection write, provider subtree appearance, popover frame change, and settled frame.

The pass/fail signal is:

- every click produces exactly one selection action;
- selection changes within one 60 Hz display interval (16.7 ms) when the main thread is idle;
- no click is ignored or accepted only after a later click;
- no old/new provider text is duplicated or displaced in captured frames;
- no provider content moves after the first settled frame except an intentional popover-height change proven by the trace.

### Temporary diagnostic instrumentation

Add temporary instrumentation only on the later diagnostic branch. Tag every line `[DEBUG-provider-switch]` and remove it before any production commit.

At both tab-button actions, emit:

```swift
ProviderSwitchTrace.record(
    surface: .settingsAgents, // use .menuPopover on the menu surface
    phase: .buttonAction,
    provider: entry.provider // use provider in MenuProviderTabStrip
)
selection = entry.provider
```

At each selection owner’s `onChange`, emit `.selectionChanged`. At the Codex and Claude content roots, emit `.contentAppeared`. For the menu surface, also observe `NSWindow.didResizeNotification` and emit `.windowResized`.

The trace should use monotonic uptime rather than wall time:

```swift
enum ProviderSwitchSurface: String {
    case settingsAgents
    case menuPopover
}

enum ProviderSwitchPhase: String {
    case buttonAction
    case selectionChanged
    case contentAppeared
    case windowResized
}

enum ProviderSwitchTrace {
    static func record(
        surface: ProviderSwitchSurface,
        phase: ProviderSwitchPhase,
        provider: AgentProvider
    ) {
        let uptime = ProcessInfo.processInfo.systemUptime
        print(
            "[DEBUG-provider-switch] uptime=\(uptime) "
                + "surface=\(surface.rawValue) "
                + "phase=\(phase.rawValue) "
                + "provider=\(provider.rawValue)"
        )
    }
}
```

Interpret the first divergent boundary:

- no `.buttonAction` → hit-testing, focus, disabled-state, or host-window event delivery;
- `.buttonAction` but delayed `.selectionChanged` → main-actor blockage or binding ownership;
- immediate `.selectionChanged` but delayed `.contentAppeared` → view construction/layout work;
- all trace phases immediate but stale/displaced captured frames → SwiftUI/AppKit compositing;
- menu-only `.windowResized` around the artifact → intrinsic-height host-window resizing remains a separate menu hypothesis.

### Ranked hypotheses to test after the loops are red

1. **Host reuse/compositing:** enum branch replacement reuses the same SwiftUI/AppKit host and transiently composites old and new provider subtrees.
   - Prediction: action/change/appearance trace phases are immediate, but raw frames contain both subtrees.
2. **Main-actor work:** provider selection coincides with synchronous layout/presentation work from a broadly observed `QuotaViewModel`.
   - Prediction: `.selectionChanged` or `.contentAppeared` is delayed in both surfaces, and the delay correlates with main-thread activity.
3. **Menu intrinsic-height resizing:** Codex and Claude content heights force the `MenuBarExtra(.window)` host to resize/reposition during the selection transaction.
   - Prediction: the menu reproduces more strongly than Settings and every jump aligns with `.windowResized`.
4. **Surface-specific hit testing:** plain-button hover/background/content-shape behavior temporarily leaves a stale hit region.
   - Prediction: pointer clicks are lost while keyboard selection still changes immediately.
5. **Settings-only `ViewThatFits` reevaluation:** the Settings selector changes between fitting and overflow branches during layout.
   - Prediction: Settings reproduces around the fitting threshold while the menu does not, and pinning the prototype width removes only the Settings symptom.

Show the ranked results and trace evidence to the user before choosing a production architecture.

### Prototype comparison

Prototype these alternatives independently for Settings and menu content:

1. Existing enum `switch` baseline.
2. A native `TabView(selection:)` container using `AgentProvider` values.
3. A stable host that keeps both provider children constructed and switches visibility/hit testing without changing outer identity.
4. An AppKit-hosted selection container (`NSTabViewController` or equivalent) that gives AppKit explicit child-controller ownership.

The prototype must preserve each surface’s existing layout and actions sufficiently for frame comparison. It must not use:

- `.id(selectedProvider)` on the detail subtree, window, or appearance owner;
- disabled-animation transactions as a masking fix;
- delayed state writes;
- window recreation;
- refresh-on-tab-switch behavior.

### Fix-selection gate

Choose a production approach only when one prototype:

- eliminates duplicated/displaced frames in both 20-cycle loops;
- accepts every mouse and keyboard selection without a stuck interval;
- preserves focus and VoiceOver;
- does not introduce menu scrolling;
- does not reset Settings scroll position or Context Rail state;
- does not refresh either provider on selection;
- passes source tests and signed-app Light/Dark acceptance.

If different causes are proven, split the fixes: do not force one shared tab abstraction merely because the symptoms look alike.

---

## Deferred Task 7: Diagnose and replace the incomplete corner-artifact fix

**Status:** Explicitly deferred. The user reports that the corner artifact remains visible after commit `575ae0e`; therefore the transparent-window change is not accepted as a fix. Do not execute this task during the source-only pass.

**Current source state:**

- `MenuPopoverChrome` clips and strokes a 14-point SwiftUI rounded rectangle.
- `MenuPopoverWindowConfigurator` asynchronously sets the host `NSWindow` to non-opaque, clear, and shadowed.
- the earlier SwiftUI shadow was removed;
- the rendered artifact remains user-observed;
- first-frame timing, host-window class, content-view masking, and shadow shape were not captured after the change.

No single cause is established. In particular, do not assume that setting `backgroundColor = .clear` changes the private `MenuBarExtra(.window)` frame, material, border, or shadow layers.

### Required corner feedback loop

After signed-app work is authorized:

1. Capture the first open from the frame before appearance through the first settled second.
2. Capture five close/reopen cycles.
3. Capture Codex → Claude → Codex switches, because intrinsic-height changes may expose different corners.
4. Repeat in Light and Dark appearance.
5. Repeat with the popover near the left and right screen edges.
6. Inspect all four corner crops at native pixel resolution; a pass requires no square fill, halo, doubled border, detached shadow, or one-frame flash outside the intended rounded shell.

### Temporary window instrumentation

On the diagnostic branch, record these values from `viewDidMoveToWindow`, `updateNSView`, `NSWindow.didBecomeKeyNotification`, and `NSWindow.didResizeNotification`:

```swift
func describe(_ window: NSWindow, phase: String) {
    let contentLayer = window.contentView?.layer
    print(
        "[DEBUG-popover-corners] phase=\(phase) "
            + "class=\(String(describing: type(of: window))) "
            + "frame=\(NSStringFromRect(window.frame)) "
            + "opaque=\(window.isOpaque) "
            + "backgroundAlpha=\(window.backgroundColor.alphaComponent) "
            + "hasShadow=\(window.hasShadow) "
            + "contentWantsLayer=\(window.contentView?.wantsLayer ?? false) "
            + "cornerRadius=\(contentLayer?.cornerRadius ?? 0) "
            + "masksToBounds=\(contentLayer?.masksToBounds ?? false)"
    )
}
```

Remove all `[DEBUG-popover-corners]` instrumentation before a production commit.

### Ranked hypotheses to test

1. **Delayed configuration flash:** `DispatchQueue.main.async` configures the window after an opaque first frame.
   - Prediction: the first captured frames show the artifact and later frames clear; `viewDidMoveToWindow` reports the window before the async mutation.
2. **Two independent corner owners:** SwiftUI clips the inner content while the private host window retains its own material/border/shadow geometry.
   - Prediction: the artifact persists after configuration and window/content layer radii differ.
3. **Shadow derived from rectangular host bounds:** `window.hasShadow` draws from the host window rather than the SwiftUI alpha mask.
   - Prediction: fill corners are clear but a square or detached shadow remains.
4. **Resize invalidation:** provider height changes resize the host and briefly expose or redraw rectangular backing.
   - Prediction: corner artifacts align with `didResize` and are stronger during provider switching.

### Prototype comparison

Compare one variable at a time:

1. Current async transparent-window configurator.
2. Synchronous configuration from an `NSView` subclass’s `viewDidMoveToWindow`.
3. System-owned window chrome: remove the custom outer clip/strokes/shadow and use the host’s native surface.
4. AppKit-owned content masking: configure the content view’s layer corner radius and `masksToBounds` while keeping the window clear.
5. The already documented square-shell fallback with no competing rounded geometry.

An AppKit-owned custom panel/popover is a separate architectural option and requires user approval because it changes ownership beyond the current `MenuBarExtra(.window)` surface.

### Fix-selection gate

Adopt a production fix only when raw signed-app frames show:

- no artifact on the first opening frame;
- no artifact after provider-driven height changes;
- one border and one shadow, not doubled layers;
- correct Light/Dark appearance;
- unchanged outside-click, Escape, focus, and dismissal behavior.

If reliable rounded ownership cannot be achieved inside `MenuBarExtra(.window)`, present the square-shell fallback and the AppKit-owned alternative to the user rather than applying another unverified transparent-window patch.

---

## Completion Criteria for This Source-Only Pass

- Expired Claude windows never participate in menu-bar provider selection.
- One monitor-owned gate serializes Claude launch, scheduled, connection, and manual reads.
- Refresh Now keeps the popover open.
- Escape is handled by the shipping popover.
- The popover contains no scrolling container.
- No more than two reset-credit expiry rows appear in the popover.
- Variable recovery/supporting copy has explicit line bounds.
- Complete underlying data remains available to Settings.
- Full Swift test suite passes.
- Swift package build passes.
- `git diff --check` passes.
- Signed-app and GUI acceptance remain explicitly unobserved.
- Provider-tab instability and the remaining corner artifact are recorded as deferred diagnostic tasks, not claimed fixed.
