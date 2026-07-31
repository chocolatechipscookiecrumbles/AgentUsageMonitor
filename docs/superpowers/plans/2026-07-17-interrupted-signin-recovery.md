# Interrupted Browser and CLI Sign-In Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** **Deferred by user direction on 2026-07-17.** This is a design and implementation plan only; do not begin source changes, tests, a build, a commit, or a push until explicitly directed.

**Goal:** After a Browser or app-owned CLI sign-in is cancelled, fails, or times out, return the running app to a usable disconnected state without relaunch, show a privacy-safe recovery explanation, restore both sign-in actions, and allow the existing disconnected-only external-login watcher to reconcile a later independent `codex login`.

**Architecture:** `CodexConnectionController` remains the only owner of connection state, the one coalesced connection task, sign-in lifecycle, and the disconnected activation/30-second watcher. A sign-in-specific failure becomes `.disconnected` plus a transient typed recovery failure, rather than the terminal-looking `.failed` state that releases the watcher. The existing `AgentConnectionFailure` supplies the safe message; `QuotaViewModel` only publishes it to the existing menu and Agents Settings surfaces. `QuotaMonitor` remains the only quota scheduler and receives no new timer, callback, or ownership.

**Tech Stack:** Swift 6.2, Swift Concurrency, Combine, AppKit, SwiftUI, XCTest, existing `CodexConnectionService`, and the signed macOS app build script.

## Problem and observed evidence

The external-login detector intentionally runs only while `CodexConnectionController.state == .disconnected`. A user cancelled the in-app Browser sign-in, then completed `codex login` independently. The Browser operation mapped its error to `.failed`; that state stopped the controller-owned activation observer and 30-second check. The app therefore remained disconnected even though the independent CLI login succeeded.

The implemented external-login feature is correct for a pre-existing `.disconnected` state and already has observed interval/activation recovery plus one persisted authentication refresh. This plan addresses the separate transition from an interrupted in-app sign-in back to that retryable state; it does not broaden the external watcher beyond `.disconnected`.

## Global constraints

- Do not execute this plan while its status is **Deferred**. Revalidate the current code and Product Follow-up 2 before starting, because the deferred interval may change the surrounding state model.
- Keep `CodexConnectionController` as the sole owner of connection state, sign-in recovery, the one `connectionTask`, the activation observer, and the disconnected 30-second watcher.
- Recover only failures produced by `signInWithBrowser()` and `signInWithCLI()`. Do not silently convert status-read failures, startup failures, or quota-refresh failures from `.failed` to `.disconnected`.
- Preserve `.missingCLI` for an unavailable executable. It has distinct install guidance and must not expose unavailable sign-in actions as successful recovery.
- Reuse `AgentConnectionFailure` and its existing user-safe copy. Do not expose raw provider output, OAuth URLs, account identity, email, tokens, credential paths, or error descriptions.
- On recovered disconnected state, restore the existing Browser and CLI actions and re-install the existing watcher. Do not add a second polling loop, sign-in watchdog, menu timer, `QuotaMonitor` scheduler, process protocol, dependency, permission, persistence schema, or credential access.
- Clear a recovery message when the user begins another sign-in, a normal connection succeeds, or the controller enters a state where the message would be misleading. A background read that remains disconnected may leave the message visible so the user can understand why the app returned there.
- Add exactly one focused regression test for the observed Browser-failure followed by external-login path. Do not add generic matrices or synthetic broad test cases.
- User-facing Settings edits must retain `SettingsPage`, `SettingsSection`, and `SettingsDescription`, and require signed-app default-size visual acceptance in Light and Dark as specified in `AGENTS.md`.

## File structure

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`: retain a typed, transient sign-in recovery failure; recover sign-in-only errors to `.disconnected`; make Browser operation injection testable without altering production behavior.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/AgentConnectionState.swift`: no new connection state case; reuse the existing `AgentConnectionFailure` type as the safe recovery notice.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`: publish the controller's recovery failure.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift` and `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexDisconnectedMenuView.swift`: show the safe recovery notice while retaining normal disconnected actions.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift` and `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`: show the same recovery notice using the shared Settings layout.
- Modify `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`: add the one deterministic regression test.
- Update `docs/product/follow-ups.md`, `docs/product/planning-board.md`, this plan, `docs/development/operating-notes.md`, `UsageProbe/README.md`, and `outline.md` after implementation with verified scope and any unrun acceptance state.

## Task 1: Add the focused regression before production changes

**Files:**
- Modify: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`

**Interfaces:**
- Consumes the existing injected status reader, activation notification seam, and a new test-only Browser sign-in operation seam.
- Produces one regression proof that a failed Browser attempt returns to `.disconnected`, preserves a safe recovery reason, and lets a later activation-triggered status read connect exactly once.

- [ ] **Step 1: Write the failing test beside the existing external-login test.**

Use a `StatusSequence` that returns `.disconnected` at startup and `.connected(AgentAccountSummary(planType: "test"))` after activation. Construct the controller with an injected Browser operation that throws `CodexConnectionServiceError.signInFailed`.

```swift
func test_failedBrowserSignInReturnsToDisconnectedAndRechecksExternalLogin() async {
    let center = NotificationCenter()
    let activation = Notification.Name("test.application-did-become-active")
    let statuses = StatusSequence([
        .disconnected,
        .connected(AgentAccountSummary(planType: "test")),
    ])
    var connectedCount = 0
    let controller = CodexConnectionController(
        onConnected: { connectedCount += 1 },
        statusReader: { await statuses.next() },
        browserSignIn: { throw CodexConnectionServiceError.signInFailed },
        notificationCenter: center,
        activationNotification: activation
    )

    controller.start()
    await waitForState(.disconnected, in: controller)
    controller.signInWithBrowser()
    await waitForState(.disconnected, in: controller)
    XCTAssertEqual(controller.recoveryFailure, .signInFailed)

    center.post(name: activation, object: nil)
    await waitForState(.connected(AgentAccountSummary(planType: "test")), in: controller)
    XCTAssertNil(controller.recoveryFailure)
    XCTAssertEqual(connectedCount, 1)
}
```

- [ ] **Step 2: Run it before production changes.**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter CodexConnectionControllerTests/test_failedBrowserSignInReturnsToDisconnectedAndRechecksExternalLogin
```

Expected: it fails to compile because `browserSignIn` and `recoveryFailure` do not exist, or fails because the old controller reaches `.failed`. Record the actual pre-change result in this plan; do not describe it as a runtime acceptance observation.

## Task 2: Make interrupted sign-in return to retryable disconnected state

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`

**Interfaces:**
- Produces `@Published private(set) var recoveryFailure: AgentConnectionFailure?` for display only.
- Keeps `AgentConnectionState` unchanged: `.disconnected` remains the lifecycle state, while `recoveryFailure` is contextual explanation rather than a parallel state machine.

- [ ] **Step 1: Add the typed recovery field and Browser-operation seam.**

Place the published field beside `state`, then add an optional injected operation with the same production default as today:

```swift
@Published private(set) var recoveryFailure: AgentConnectionFailure?

private let browserSignIn: @Sendable () async throws -> AgentAccountSummary

init(
    service: CodexConnectionService = CodexConnectionService(),
    onConnected: @escaping @MainActor () -> Void,
    statusReader: (@Sendable () async -> AgentConnectionState)? = nil,
    browserSignIn: (@Sendable () async throws -> AgentAccountSummary)? = nil,
    notificationCenter: NotificationCenter = .default,
    activationNotification: Notification.Name? = nil,
    disconnectedCheckInterval: Duration = .seconds(30)
) {
    // Keep existing assignments.
    self.browserSignIn = browserSignIn ?? { [service] in
        try await service.startBrowserLogin()
    }
}
```

Have `signInWithBrowser()` pass the stored `browserSignIn` operation to `beginSignIn`. Do not add a service protocol or duplicate the CLI operation merely for this one regression.

- [ ] **Step 2: Centralize sign-in failure recovery.**

Add one helper used by both Browser and CLI `catch` blocks. Cancellation should create `.signInFailed`, because it is an incomplete sign-in from the user's perspective; `CodexConnectionServiceError` values use the existing `mappedFailure(_:)` classification.

```swift
private func recoverFromSignIn(error: Error) {
    let recoveredState: AgentConnectionState
    if error is CancellationError {
        recoveryFailure = .signInFailed
        recoveredState = .disconnected
    } else {
        let failureState = mappedFailure(error)
        guard case .failed(let failure) = failureState else {
            recoveryFailure = nil
            applyState(failureState) // Preserve .missingCLI.
            connectionTask = nil
            return
        }
        recoveryFailure = failure
        recoveredState = .disconnected
    }
    applyState(recoveredState)
    connectionTask = nil
}
```

Replace each sign-in `catch` path with the helper. Keep the `Task.isCancelled` guard that prevents a torn-down controller from publishing state. Do not use this helper from `detectConnection`; a failed silent status read retains its existing `.failed` handling.

- [ ] **Step 3: Clear the contextual failure only at semantic boundaries.**

Clear it immediately before a new Browser or CLI attempt, and in `completeSignIn(_:)`. Clear it when transitioning to `.missingCLI`; do not clear it merely because an activation or interval recheck still reads `.disconnected`. This preserves useful recovery context while the existing watcher waits for an independently completed login.

The expected lifecycle is:

```text
signingIn(browser|cli) --cancel/fail/timeout--> disconnected + recoveryFailure
                                               | actions enabled
                                               | activation/30-second watcher restored
                                               v
                         independent codex login --> connected + nil recoveryFailure
```

## Task 3: Present the recovery notice without creating another owner

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexDisconnectedMenuView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`

- [ ] **Step 1: Publish rather than reinterpret the failure.**

In `QuotaViewModel`, add `@Published private(set) var connectionRecoveryFailure: AgentConnectionFailure?` and subscribe to `connectionController.$recoveryFailure`. Do not derive or mutate it from refresh state, menu state, or Settings.

- [ ] **Step 2: Keep the menu in normal disconnected mode.**

Pass the optional recovery failure through `QuotaMenuView` into `CodexDisconnectedMenuView`. For `.disconnected`, render `recoveryFailure?.displayMessage` before the ordinary disconnected guidance and use the existing warning emphasis for that explicit recovery message. The title remains “Codex isn’t connected”; both sign-in buttons remain enabled.

Do not add a timer, a dynamic menu row, a second check action, or a menu-owned connection read.

- [ ] **Step 3: Show the same notice in Agents Settings using shared layout primitives.**

Pass the value through `AgentsSettingsView` to `CodexAgentSettingsView`. When state is `.disconnected` and a recovery failure exists, render `SettingsDescription(recoveryFailure.displayMessage)` as wrapped callout-level guidance followed by the ordinary disconnected explanation. Keep `SettingsPage`, `SettingsSection`, and `SettingsDescription`; do not introduce a `Form`, `LabeledContent`, or page-local alignment constants.

## Task 4: Verify the regression and signed-app behavior

**Files:**
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`

- [ ] **Step 1: Run focused and full deterministic checks.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter CodexConnectionControllerTests/test_failedBrowserSignInReturnsToDisconnectedAndRechecksExternalLogin
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
```

The focused test must prove the old failure/recovery boundary. Full tests must pass; neither command substitutes for native behavior acceptance.

- [ ] **Step 2: Build and verify the signed app.**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist
```

- [ ] **Step 3: Run the manual acceptance sequence without disturbing the active account.**

In an isolated Codex home/session where feasible:

1. Start disconnected, begin Browser sign-in, and cancel or let it fail naturally. Confirm the app promptly returns to the normal disconnected title, shows safe recovery guidance, and enables both sign-in actions without relaunch.
2. Complete `codex login` independently, without pressing an in-app action. Confirm activation or the existing 30-second bound changes the app to connected; inspect the existing sanitized diagnostics record to verify exactly one new `authentication` refresh if that count can be observed safely.
3. Repeat Browser sign-in and complete it successfully. Confirm the recovery message clears, the connected state is shown, and no duplicate refresh is evident.
4. If a safe CLI timeout/failure cannot be manufactured, record it as **Not run** rather than claiming Browser evidence covers CLI behavior.
5. Open the signed Settings window at the default 680 × 560-point content size in Light and Dark. Inspect Agents Settings with the recovery notice for clipping, inaccessible content, bad contrast, and disabled/action state errors. Leave user-owned app instances untouched.

## Task 5: Synchronize evidence and prepare the manual PR draft

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-interrupted-signin-recovery.md`
- Modify: `docs/product/follow-ups.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/development/operating-notes.md`, `UsageProbe/README.md`, and `outline.md`
- Create: `.worktrees/interrupted-signin-recovery-PR.md` (filled manual PR draft only)

- [ ] Record pre-change and post-change focused-test results, signed-build results, manual observations, and explicit unrun paths. Update Product Follow-up 2 and the planning board from **Deferred** only when implementation is explicitly resumed.
- [ ] Document the normal post-failure user flow and the privacy boundary in operating guides only after behavior is verified.
- [ ] Run `git diff --check`, confirm all changed Markdown links and heading anchors resolve, then create a filled PR template using the repository evidence-rich PR template. The user creates any GitHub PR manually; do not invoke PR creation.

## Acceptance criteria

- A failed, cancelled, or timed-out Browser/CLI attempt no longer leaves the app in a state that disables the disconnected watcher or requires relaunch before another attempt.
- `.missingCLI` remains distinct and preserves install guidance.
- The recovery explanation is an existing typed, privacy-safe failure message; no raw provider or credential data reaches the menu, Settings, diagnostics, or test output.
- An interrupted Browser sign-in followed by an external CLI login reaches connected through the existing activation/interval watcher and invokes the authentication refresh callback once.
- The menu and Settings show the recovered disconnected state with enabled actions and no layout/contrast regression.
- No second scheduler, watcher, persistence schema, permission, dependency, or native-menu dynamic update is introduced.

## Deferred handoff

Do not implement this plan until explicitly resumed. On resumption, first fast-forward from `origin/main`, confirm the external-login detector and Product Follow-up 2 still match the code, create an isolated implementation worktree, run the focused test red, and then execute Tasks 1–5 in order.
