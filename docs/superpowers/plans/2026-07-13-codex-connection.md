# Codex Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the menu-bar app an explicit Codex connection stage with provider-owned browser sign-in and a visible Codex CLI sign-in path, then return to live quota monitoring after authentication succeeds.

**Architecture:** A dedicated connection service owns short-lived Codex CLI and app-server processes. A main-actor connection controller publishes a provider-neutral state machine to `QuotaViewModel`; the menu and Agents Settings render that state without parsing errors or reading credentials. Codex continues to own token storage and refresh, and `QuotaMonitor` remains the only quota refresh/scheduling owner.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation `Process`/`Pipe`, Codex app-server JSON-RPC v2, existing Combine-based view-model bindings.

## Global Constraints

- Work on `feature/codex-connection`, stacked on `feature/adaptive-refresh` in the existing linked worktree.
- Codex is the only active provider; Claude Code and GitHub Copilot remain visible but planned.
- Connection and sign-in handling must never open `~/.codex/auth.json`, extract access or refresh tokens, display account identity, persist raw account responses, or surface raw authentication errors. The established quota collector may continue ephemerally parsing its existing allowlisted account fields to derive the one-way fingerprint; it must not log or persist the raw response or email.
- Browser sign-in must use Codex-managed ChatGPT authentication through `account/login/start`; the app opens only the provider-generated `authUrl` and waits for the matching `account/login/completed` event.
- CLI sign-in must visibly open Terminal and run the located Codex executable's `login` command, then poll `codex login status` and confirm the result with `account/read`.
- Do not add logout, account switching, API-key entry, device-code login, provider expansion, or a custom credential form.
- Keep the native inline `MenuBarExtra`; do not use `.menuBarExtraStyle(.window)` and do not reintroduce SwiftUI self-scheduling menu timers.
- Keep Settings and Quit at the bottom of every menu stage. Keep credits and reset-credit details in the connected menu stage.
- Do not add or run automated test cases. Verification is compilation, a signed app build, read-only CLI/status inspection, process-survival checks, and documented manual UI acceptance.
- Update this plan, the daily-driver roadmap, `outline.md`, `how-to.md`, and `UsageProbe/README.md` with implemented behavior and verification evidence.

---

### Task 1: Define the connection domain contract

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/AgentConnectionState.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitoringState.swift`

**Interfaces:**
- Produces: `AgentConnectionState`, `AgentSignInMethod`, `AgentConnectionFailure`, `AgentAccountSummary`, and `RefreshReason.authentication`.
- Consumes: no UI or persistence dependencies.

- [x] Define `AgentConnectionState` cases for checking, missing CLI, disconnected, signing in, connected, and failed.
- [x] Give connection failures stable, actionable display copy without storing raw provider output.
- [x] Add `.authentication` as the refresh reason used only after a newly confirmed connection.
- [x] Confirm every state and associated value is `Equatable` and `Sendable`.

### Task 2: Add read-only Codex status and browser sign-in services

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionService.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexAppServerSession.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexProtocolModels.swift`

**Interfaces:**
- Consumes: `CodexExecutableLocator.locate()`, the established `initialize`/`initialized` handshake, and the official `account/read`, `account/login/start`, and `account/login/completed` shapes.
- Produces: `CodexConnectionService.readStatus() async -> AgentConnectionState`, `startBrowserLogin() async throws -> AgentAccountSummary`, and `waitForCLILogin() async throws -> AgentAccountSummary`.

- [x] Reuse the existing executable locator and extract only the minimal line-delimited JSON-RPC message collection needed by quota and connection sessions.
- [x] Implement `account/read` with `refreshToken: false`; map `account: null` to disconnected and retain only plan type in `AgentAccountSummary`.
- [x] Implement `account/login/start` with `{type: "chatgpt"}`, validate the returned HTTPS `authUrl` plus `loginId`, and open the URL with `NSWorkspace`.
- [x] Keep the app-server process alive until the matching completion notification arrives, handle cancellation/timeouts by terminating it, then confirm the account with a new `account/read` call.
- [x] Implement CLI-status polling with a finite timeout and no raw-output persistence; require a subsequent successful `account/read` before reporting connected.

### Task 3: Coordinate connection state and user actions

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- Modify: `CodexUsageMonitor/Resources/Info.plist`

**Interfaces:**
- Consumes: `CodexConnectionService`, `QuotaMonitor.refresh(reason:)`, and `NSAppleScript` or an equivalent visible Terminal launch.
- Produces: published `connectionState`, `signInWithBrowser()`, `signInWithCLI()`, and `checkCodexConnection()` on `QuotaViewModel`.

- [x] Check connection status once at startup without blocking quota history or notification initialization.
- [x] Recheck typed account status after an unavailable quota refresh so an external logout transitions the running app to the disconnected stage.
- [x] Make repeated sign-in clicks idempotent while one connection task is active.
- [x] For CLI sign-in, activate Terminal and execute the shell-quoted located command `<codex executable> login`, preserving an explicit `CODEX_HOME`; keep the app in signing-in state while bounded status polling runs.
- [x] Declare a narrowly worded Terminal automation usage description for the user-initiated CLI action.
- [x] On either successful path, publish connected state and invoke `QuotaMonitor.refresh(reason: .authentication)` exactly once; coalesce one pending authentication refresh if another collection is already in flight.
- [x] Cancel any owned task during controller teardown and map cancellation back to a retryable disconnected state rather than an error alert.

### Task 4: Render the disconnected menu stage

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexDisconnectedMenuView.swift`

**Interfaces:**
- Consumes: `QuotaViewModel.connectionState`, browser/CLI sign-in actions, the existing Settings opener, and application termination.
- Produces: mutually exclusive connection and connected-quota menu stages.

- [x] When checking, show `Checking Codex connection…` without presenting stale quota as current.
- [x] When disconnected, show `Codex isn’t connected`, concise guidance, `Sign in with browser`, and `Sign in with Codex CLI…`.
- [x] While signing in, keep both paths visible but disabled and show which path is in progress.
- [x] For recoverable failure, show actionable normalized copy and both retry actions; for missing CLI, show installation guidance and disable sign-in actions.
- [x] Keep `Settings…` and `Quit Codex Usage Monitor` as the final two actions in every stage.
- [x] Preserve the existing connected quota rows, alert toggle, live refresh countdown, refresh action, confirmed/completed state, cached/paused state, credits, and reset-credit details unchanged.

### Task 5: Complete the Codex Agents settings detail

**Files:**
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift`

**Interfaces:**
- Consumes: the same provider-neutral connection state and sign-in actions as the menu.
- Produces: a Codex detail pane whose status matches the menu; other provider panes remain read-only planned states.

- [x] Replace the planned-connection placeholder with actual checking, disconnected, signing-in, connected, missing-CLI, and failed status copy.
- [x] Show both sign-in actions for retryable disconnected states and keep privacy copy stating that credentials and account identity are not displayed.
- [x] Make the Codex sidebar subtitle derive from connection state; leave Claude Code and GitHub Copilot unchanged.
- [x] Confirm repeated menu Settings actions focus the existing Settings scene and do not create an additional connection controller.

### Task 6: Document and verify the branch

**Files:**
- Modify: `docs/superpowers/plans/2026-07-13-codex-connection.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md`
- Modify: `outline.md`
- Modify: `how-to.md`
- Modify: `UsageProbe/README.md`

**Interfaces:**
- Consumes: final implementation and manual acceptance evidence.
- Produces: a user-facing operating guide and accurate roadmap status.

- [x] Run `swift build --package-path CodexUsageMonitor` and require a clean exit.
- [x] Run `Scripts/build-app.sh`, confirm the signed app bundle is produced, launch it, and verify the process survives its launch refresh.
- [x] Manually verify the disconnected menu stage using an isolated Codex home or equivalent non-destructive setup: both sign-in choices, signing-in feedback, Settings focus, and Quit placement.
- [x] Manually verify successful browser/CLI authentication transitions to the connected quota stage and triggers one quota refresh.
- [x] Record what was verified, what remains manual, and the no-credential-access boundary in all required documentation.

## Implementation and verification notes

- The final connection state and account summary types are provider-neutral; Codex-specific process/protocol details remain behind `CodexConnectionService`.
- `swift build --package-path CodexUsageMonitor` completed successfully with Swift 6.2 after the connection, menu, Settings, and authentication-refresh changes.
- The existing `--live-read-once` diagnostic returned a confirmed live Codex result after the app-server process wrapper was shared, verifying that quota collection still works.
- `Scripts/build-app.sh` produced and ad-hoc signed the bundle after `plutil -lint` accepted the Terminal automation usage description.
- A new signed instance survived startup connection detection and its launch refresh, and no diagnostic report newer than the previously documented 16:03 crashes appeared.
- An isolated empty `CODEX_HOME` reported `Not logged in`; the app launched with that environment and remained alive for a ten-second disconnected-state process check.
- A PID-targeted automated attempt to inspect the isolated menu through System Events was blocked because `osascript` does not have Assistive Access (`-1719`). Verification did not change macOS Accessibility permissions.
- User-reported manual acceptance on 2026-07-13 confirmed the disconnected menu stage and successful browser/CLI authentication transitions. The implementation did not log out or alter the connected account automatically to manufacture those states.
- Independent read-only review found no critical issues. Its two important findings (custom `CODEX_HOME` propagation and bounded subprocess shutdown) and two minor findings (stale disconnected plan display and privacy wording) were fixed; follow-up review reported no remaining critical or important issue.
- Privacy boundary: source inspection confirms the connection module contains no auth-file read, token field, email field, account-response persistence, or raw-error UI path. Codex owns browser callback validation, token exchange, storage, and refresh.
- Known limitation recorded on 2026-07-17: a user can remain on the disconnected stage after completing `codex login` independently, without first selecting either app sign-in action. `start()` reads status once; the bounded CLI watcher is created only by `signInWithCLI()`; and the later silent recheck is coupled to a failed quota refresh rather than to a newly valid external Provider Session. Runtime reproduction was not manufactured against the user's active account. The planned investigation and privacy-safe acceptance boundary are tracked in [Product Follow-up 8](../../product/follow-ups.md#8-detect-an-external-codex-login-while-disconnected).

## Self-review

- Spec coverage: explicit disconnected stage, two sign-in options, Settings/Quit placement, missing CLI, recoverable failures, post-login refresh, Agents status, privacy boundary, and documentation all have tasks.
- Scope control: logout, account switching, token handling, API keys, device code, provider expansion, dashboard, and appearance remain absent.
- Type consistency: views consume `AgentConnectionState`; only the controller mutates it; only `QuotaMonitor` refreshes quota and schedules the next refresh.
- Verification constraint: no automated test files or test commands are added; all checks follow the user's standing build/manual-verification instruction.
