# External Codex Login Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect a Codex login completed outside the app while the running monitor is disconnected, publish the connected stage within 30 seconds or immediately after activation, and start exactly one authentication refresh.

**Architecture:** `CodexConnectionController` remains the sole owner of external Provider Session detection. While—and only while—its typed state is `.disconnected`, it owns one cancellable 30-second task that silently calls the existing read-only `CodexConnectionService.readStatus()`. It also observes application activation and performs the same silent recheck immediately. A first non-startup transition to `.connected` invokes the existing `onConnected` callback once; `QuotaMonitor` remains the only quota-refresh scheduler.

**Tech Stack:** Swift 6.2, Swift Concurrency, Combine, AppKit `NSApplication.didBecomeActiveNotification`, Foundation `NotificationCenter`, existing Codex app-server `account/read`, XCTest, and the signed macOS app build script.

## Global Constraints

- Before execution, fast-forward the implementation base to current `origin/main` and confirm whether the notification-delivery fix has merged; create the isolated implementation worktree from that synchronized base.
- Guarantee a maximum 30-second disconnected-state detection interval and recheck immediately when the app becomes active.
- Keep all external-login status reads in `CodexConnectionController`; `QuotaViewModel`, `QuotaMonitor`, `MenuBarExtra`, and menu presentation must not start a watcher, timer, or second scheduler.
- Reuse only `CodexConnectionService.readStatus()`, which uses the provider app server's `account/read`; never read `auth.json`, tokens, email, raw provider output, or credential files.
- Preserve the existing `CODEX_HOME` handling, in-app Browser/CLI flows, external-logout recheck, user-initiated **Check again**, and bounded app-owned CLI watcher.
- Coalesce activation, interval, manual, refresh-failure, and in-app sign-in checks with the existing single `connectionTask` guard.
- Stop and release the disconnected watcher and activation observer after connection, missing-CLI state, a non-disconnected failure state, sign-in start, or controller teardown.
- A first observed `.connected` result after a non-startup disconnected check invokes `onConnected` exactly once. Startup detection does not add an authentication refresh because normal monitor launch refresh remains authoritative.
- Keep background checks visually silent: they must not replace the disconnected menu with `.checking`; a failed read must remain retryable through the existing sign-in actions and **Check again**, never leave `.checking` or `.signingIn` stuck.
- Do not add broad suites or generic test cases. Add one focused deterministic regression test for the external-login activation path; record the 30-second timer and real app-server behavior as signed-app manual acceptance.
- Do not add dependencies, permissions, logout, account switching, provider expansion, a credential form, or a true native-menu countdown.

---

## File structure

- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`: own the activation observer, one cancellable disconnected-state task, testable read-status injection, typed state-transition side effects, and exactly-once post-external-login refresh callback.
- Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`: one deterministic regression test proving an activation-triggered external status change reconnects once without a menu or quota scheduler.
- Modify `docs/product/follow-ups.md`, `docs/product/planning-board.md`, and `docs/superpowers/plans/2026-07-13-codex-connection.md`: link the dedicated plan and promote the recorded problem from **Needs plan** to **Queued**.
- Modify `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`, `outline.md`, `how-to.md`, and `UsageProbe/README.md`: after implementation, describe the 30-second/activation behavior, privacy boundary, acceptance evidence, and any unrun live state without overstating coverage.

## Task 1: Write the external-login activation regression first

**Files:**
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`

**Interfaces:**
- Consumes: `AgentConnectionState`, `AgentAccountSummary`, `NotificationCenter`, and an injected `@Sendable () async -> AgentConnectionState` status reader.
- Produces: a `CodexConnectionController` initializer accepting `statusReader`, `notificationCenter`, and `activationNotification` test seams while retaining production defaults.

- [x] **Step 1: Add a deterministic sequence source and the failing regression test.**

```swift
import XCTest
@testable import CodexUsageMonitor

private actor StatusSequence {
    private var values: [AgentConnectionState]

    init(_ values: [AgentConnectionState]) { self.values = values }

    func next() -> AgentConnectionState {
        guard !values.isEmpty else { return .disconnected }
        return values.removeFirst()
    }
}

@MainActor
final class CodexConnectionControllerTests: XCTestCase {
    func test_activationRecheckConnectsOnceAfterExternalLogin() async {
        let center = NotificationCenter()
        let activation = Notification.Name("test.application-did-become-active")
        let sequence = StatusSequence([
            .disconnected,
            .connected(AgentAccountSummary(planType: "test")),
        ])
        var connectedCount = 0
        let controller = CodexConnectionController(
            onConnected: { connectedCount += 1 },
            statusReader: { await sequence.next() },
            notificationCenter: center,
            activationNotification: activation
        )

        controller.start()
        await waitForState(.disconnected, in: controller)
        center.post(name: activation, object: nil)
        await waitForState(.connected(AgentAccountSummary(planType: "test")), in: controller)
        center.post(name: activation, object: nil)
        await Task.yield()

        XCTAssertEqual(connectedCount, 1)
    }

    private func waitForState(
        _ expected: AgentConnectionState,
        in controller: CodexConnectionController
    ) async {
        for _ in 0..<100 where controller.state != expected {
            await Task.yield()
        }
        XCTAssertEqual(controller.state, expected)
    }
}
```

- [x] **Step 2: Run the test before implementation.**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter CodexConnectionControllerTests/test_activationRecheckConnectsOnceAfterExternalLogin
```

Expected: the test does not compile because the controller has no injected status/notification seams and no activation observer. Do not proceed until this is the observed reason for failure.

## Task 2: Make connection-state transitions own the watcher lifecycle

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift`

**Interfaces:**
- Consumes: `CodexConnectionService.readStatus() async -> AgentConnectionState`, the test-injected equivalent reader, and `NSApplication.didBecomeActiveNotification`.
- Produces: `start()`, `checkConnection()`, and `recheckConnection()` with one coalesced task; a 30-second disconnected-only watch; and one `onConnected()` invocation for a new external connection.

- [x] **Step 1: Add controller-owned dependencies and teardown.**

Add these stored properties next to `connectionTask`:

```swift
private let statusReader: @Sendable () async -> AgentConnectionState
private let notificationCenter: NotificationCenter
private let activationNotification: Notification.Name
private let disconnectedCheckInterval: Duration
private var disconnectedWatchTask: Task<Void, Never>?
private var activationObserver: ActivationObserver?
```

Extend the initializer without changing production call sites:

```swift
init(
    service: CodexConnectionService = CodexConnectionService(),
    onConnected: @escaping @MainActor () -> Void,
    statusReader: (@Sendable () async -> AgentConnectionState)? = nil,
    notificationCenter: NotificationCenter = .default,
    activationNotification: Notification.Name? = nil,
    disconnectedCheckInterval: Duration = .seconds(30)
) {
    let activationNotification = activationNotification ?? NSApplication.didBecomeActiveNotification
    self.service = service
    self.onConnected = onConnected
    self.statusReader = statusReader ?? { [service] in await service.readStatus() }
    self.notificationCenter = notificationCenter
    self.activationNotification = activationNotification
    self.disconnectedCheckInterval = disconnectedCheckInterval
}
```

Use a small token owner so the controller does not directly cross the AppKit observer token into `deinit`:

```swift
private final class ActivationObserver {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter,
        notification: Notification.Name,
        onActivation: @escaping @Sendable () -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(forName: notification, object: nil, queue: .main) { _ in
            onActivation()
        }
    }

    func cancel() {
        guard let token else { return }
        notificationCenter.removeObserver(token)
        self.token = nil
    }

    deinit { cancel() }
}
```

The controller cancels its two tasks in `deinit`; releasing `activationObserver` lets the helper remove its token.

- [x] **Step 2: Centralize status results and start only one 30-second watcher.**

Replace direct status-result assignment in `detectConnection` with `applyDetectedState(_:trigger:)`. Use this trigger type:

```swift
private enum ConnectionCheckTrigger: Equatable {
    case startup
    case userInitiated
    case refreshFailure
    case applicationActivation
    case disconnectedInterval

    var showsCheckingState: Bool {
        self == .startup || self == .userInitiated
    }
}
```

Implement the state boundary:

```swift
private func applyDetectedState(
    _ detectedState: AgentConnectionState,
    trigger: ConnectionCheckTrigger
) {
    let wasConnected = state.isConnected
    applyState(detectedState)

    if trigger != .startup, !wasConnected, detectedState.isConnected {
        onConnected()
    }
}

private func startDisconnectedWatchIfNeeded() {
    guard disconnectedWatchTask == nil else { return }
    let interval = disconnectedCheckInterval
    disconnectedWatchTask = Task { [weak self] in
        do {
            while !Task.isCancelled {
                try await Task.sleep(for: interval)
                guard let self, !Task.isCancelled,
                      case .disconnected = self.state
                else { return }
                self.detectConnection(trigger: .disconnectedInterval)
            }
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }
}

private func stopDisconnectedWatch() {
    disconnectedWatchTask?.cancel()
    disconnectedWatchTask = nil
}

private func applyState(_ newState: AgentConnectionState) {
    state = newState
    if case .disconnected = newState {
        startDisconnectedWatchIfNeeded()
        startActivationObserverIfNeeded()
    } else {
        stopDisconnectedWatch()
        stopActivationObserver()
    }
}

private func startActivationObserverIfNeeded() {
    guard activationObserver == nil else { return }
    activationObserver = ActivationObserver(
        notificationCenter: notificationCenter,
        notification: activationNotification
    ) { [weak self] in
        Task { @MainActor [weak self] in
            self?.recheckAfterApplicationActivation()
        }
    }
}

private func stopActivationObserver() {
    activationObserver?.cancel()
    activationObserver = nil
}

private func recheckAfterApplicationActivation() {
    guard case .disconnected = state else { return }
    detectConnection(trigger: .applicationActivation)
}
```

Map public call sites to triggers: `start()` uses `.startup`; **Check again** uses `.userInitiated`; the existing quota-refresh failure path uses `.refreshFailure`; and the interval/activation helpers above use their matching internal cases. `detectConnection(trigger:)` must keep the existing `connectionTask == nil` guard, call `statusReader()`, clear `connectionTask`, and never set `.checking` for activation, interval, or refresh-failure checks.

- [x] **Step 3: Preserve in-app sign-in semantics.**

Route all state assignments in `completeSignIn`, cancellation handling, and mapped sign-in failures through one helper that stops the disconnected watcher whenever state is not `.disconnected`. Keep `completeSignIn(_:)` as the only browser/CLI path that calls `onConnected()` directly. Do not call `onConnected()` from startup status detection, and do not call it again when an already-connected controller receives another connected status.

- [x] **Step 4: Run the focused regression test and inspect the exact behavior.**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter CodexConnectionControllerTests/test_activationRecheckConnectsOnceAfterExternalLogin
```

Expected: PASS; the startup status becomes disconnected, the injected activation notification changes it to connected, and two activation posts invoke `onConnected` once.

- [x] **Step 5: Commit the behavioral slice.**

```bash
git add \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/CodexConnectionControllerTests.swift
git commit -m "Detect external Codex logins while disconnected"
```

### Task 1/2 verification evidence (2026-07-17)

- RED: Before the controller implementation, the focused test failed to compile with `extra arguments at positions #2, #3, #4 in call`; the compiler identified the existing `init(service:onConnected:)` as the only initializer.
- GREEN: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor --filter CodexConnectionControllerTests/test_activationRecheckConnectsOnceAfterExternalLogin` passed: `Executed 1 test, with 0 failures (0 unexpected)`.
- Full package verification: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor` passed: `Executed 7 tests, with 0 failures (0 unexpected)`.
- Whitespace verification: `git diff --check` passed with no output.

## Task 3: Build the signed app and perform isolated external-login acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-07-17-external-codex-login-detection.md`

**Interfaces:**
- Consumes: the signed `.app`, a temporary isolated `CODEX_HOME`, the user's own explicit Codex login action, and the controller's 30-second/activation triggers.
- Produces: dated evidence for the external-login boundary without reading credentials or disturbing a pre-existing app process.

- [x] **Step 1: Build and validate the signed application.**

Run:

```bash
cd CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 .build/CodexUsageMonitor.app
plutil -lint .build/CodexUsageMonitor.app/Contents/Info.plist
```

Expected: the app builds, signature verification succeeds, and `Info.plist` reports `OK`.

### Task 3 interim verification evidence (2026-07-17)

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh` built the signed `.app` successfully.
- `codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app` reported that the app is valid on disk and satisfies its Designated Requirement.
- `plutil -lint CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/Info.plist` reported `OK`.
- The isolated external-login checks remain pending the user's explicit `codex login` action; no credentials, account files, or user-owned app process have been touched.

- [x] **Step 2: Prepare, but do not destroy, an isolated Codex home.**

Run only from a dedicated audit shell:

```bash
mktemp -d /private/tmp/codex-usage-monitor-external-login.XXXXXX
```

Record the resulting path. Launch only the newly built app with `CODEX_HOME` set to that exact path, record its PID, and confirm the app reaches the disconnected menu stage. Do not alter the user's normal Codex home, log out a user-owned app, or remove the temporary directory until the user accepts cleanup.

- [ ] **Step 3: Verify the interval trigger.**

Without selecting either in-app sign-in action, run `codex login` independently in Terminal with the same isolated `CODEX_HOME`. Leave the monitor running and do not open the menu to trigger activation. Confirm within 30 seconds that it replaces the disconnected stage with connected quota content and requests one authentication refresh. Open Diagnostics or otherwise inspect the app-owned refresh reason to confirm exactly one authentication refresh, not a new scheduler or repeated connection process.

- [ ] **Step 4: Verify the activation trigger and coalescing.**

Repeat with a fresh isolated disconnected session. Complete the independent `codex login`, then activate the still-running monitor before the 30-second interval expires. Confirm it reconnects immediately. Repeatedly open and close the native menu and reactivate the app while status checking is in flight; confirm there is one connection transition and one authentication refresh, no duplicate watcher, status process, or scheduler.

- [ ] **Step 5: Verify negative and teardown paths.**

With the same isolated home, confirm a failed status read remains retryable through the existing sign-in actions and **Check again** without a stuck `.checking` or `.signingIn` state. Confirm the existing in-app Browser and CLI paths, custom `CODEX_HOME` propagation, external-logout detection after an unavailable quota refresh, sleep/wake refresh behavior, and app teardown still work. Record any state that cannot be safely manufactured as **Not run** rather than inferring coverage.

- [x] **Step 6: Record exact evidence and commit it.**

Record command outcomes, the documented 30-second bound, observed refresh count, menu-state results, process ownership/cleanup, and all unrun states in this plan. Do not record tokens, email, raw provider responses, raw errors, or the isolated-home contents.

```bash
git add docs/superpowers/plans/2026-07-17-external-codex-login-detection.md
git commit -m "Record external login detection acceptance"
```

### Task 3 acceptance evidence (2026-07-17)

- Signed build, signature, and `Info.plist` verification passed before manual acceptance.
- Interval route: with a fresh isolated `CODEX_HOME`, the user completed `codex login` independently without selecting an in-app sign-in action or activating the monitor. The monitor changed from disconnected to connected after roughly five seconds. That satisfies the 30-second bound; the time remaining to the next watcher tick was not observed.
- Activation route: with a separate fresh isolated `CODEX_HOME`, the user completed independent `codex login`, then activated the monitor before the next interval. The monitor connected promptly after roughly two to three seconds.
- The two temporary audit instances were app-owned processes, not a user-owned app process. Their isolated homes have not been removed because cleanup has not yet been accepted.
- **Not run:** Diagnostics confirmation of exactly one `.authentication` refresh; repeated activation/menu-event coalescing while a status check is in flight; failed-read retryability; Browser/CLI regression, custom-home propagation beyond these independent-login paths; external logout, sleep/wake, controller teardown, and audit cleanup. No claim is made for those states.

## Task 4: Synchronize product and operating documentation

**Files:**
- Modify: `docs/product/follow-ups.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-connection.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/superpowers/plans/2026-07-17-external-codex-login-detection.md`

**Interfaces:**
- Consumes: completed implementation and Task 3 evidence.
- Produces: one status model and accurate user instructions for independent external login.

- [x] **Step 1: Update planning status and links.**

Change Product Follow-up 8 and the matching bug-board entry from **Needs plan** to **Verification** only after Task 2 is implemented; before implementation they remain **Queued** and link this plan. Add this plan to the planning-board coverage index. Replace the old connection-plan known-limitation text with a link to this plan and its final evidence; update the roadmap/outline only with the actual completed state.

- [x] **Step 2: Update user-facing instructions only after the signed acceptance passes.**

Add this bounded statement to `how-to.md` and the corresponding native-app section of `UsageProbe/README.md`:

> If you run `codex login` independently while Codex Usage Monitor is disconnected, it rechecks the same Codex home immediately when the app becomes active and at most 30 seconds later while it remains disconnected. The check uses read-only `account/read`; it does not read credential files or start another quota schedule.

State the same ownership and privacy boundary in `outline.md`. If Task 3 has any unrun check, name it rather than claiming complete external-login acceptance.

- [x] **Step 3: Run documentation and final code verification.**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash CodexUsageMonitor/Scripts/build-app.sh
git diff --check
```

Expected: the focused regression and existing package tests pass, the signed app builds, and `git diff --check` reports no whitespace errors. Record live app observations separately from these commands.

### Task 4 verification evidence (2026-07-17)

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path CodexUsageMonitor` passed: 7 XCTest cases, 0 failures.
- The signed app rebuilt successfully; `codesign --verify --deep --strict --verbose=2` reported a valid app satisfying its Designated Requirement, and `plutil -lint` reported `OK`.
- `git diff --check` passed with no output.

- [x] **Step 4: Commit synchronized documentation.**

```bash
git add \
  docs/product/follow-ups.md \
  docs/product/planning-board.md \
  docs/superpowers/plans/2026-07-13-codex-connection.md \
  docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md \
  docs/superpowers/plans/2026-07-17-external-codex-login-detection.md \
  outline.md \
  how-to.md \
  UsageProbe/README.md
git commit -m "Document external Codex login detection"
```

## Plan self-review

- **Spec coverage:** Tasks 1–2 cover controller ownership, 30-second interval, immediate activation, coalescing, stable external connection transition, and exactly-once authentication refresh. Task 3 covers isolated `CODEX_HOME`, native-menu behavior, in-app flow preservation, external logout, teardown, and unobserved states. Task 4 synchronizes every listed plan and user-facing document.
- **Scope control:** The plan does not add a provider, credentials, auth-file access, network reachability inference, a quota scheduler, a menu timer, a new permission, or UI redesign.
- **Regression coverage:** One deterministic activation-path regression test is written before production code. The real 30-second app-server path remains a signed-app manual acceptance boundary because it depends on macOS application activation and an independently authenticated CLI session.
- **Type consistency:** `CodexConnectionController` consumes `() async -> AgentConnectionState`, continues publishing `AgentConnectionState`, and invokes the existing `@MainActor onConnected` closure. `QuotaMonitor.refresh(reason: .authentication)` remains behind that closure and retains scheduling ownership.
