# Claude Delegated OAuth and Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `systematic-debugging` and `diagnosing-bugs` for the capability gate, then `subagent-driven-development` or `executing-plans` for accepted implementation tasks. Use `swift-security-expert` for credential work and `writing-for-interfaces` for every user-facing state. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unreliable Claude first-run path with one explicit, provider-owned OAuth flow that reaches a coherent usage state or names the exact blocker and retry.

**Architecture:** **Fit — existing MVVM with actor-isolated services.** `ClaudeConnectionController` remains the presentation-state owner, `ClaudeAuthenticationService` owns provider-CLI status/login effects, and `ClaudeUsageMonitor` remains the sole refresh/source-hierarchy owner. A dedicated Keychain actor owns any app-issued credential; views receive closures and never access CLI, Keychain, or network services.

**Tech Stack:** Swift 6.2, Foundation `Process`, AppKit/AppleScript for a visible Terminal command, Security/Keychain, URLSession, Claude Code CLI 2.1.220+ capability contract, XCTest. No new dependency and no custom PKCE implementation.

## Global Constraints

- Claude enrollment from the first-launch plan is required before any auth status, Keychain, usage endpoint, passive status-line, cache, or CLI probe work begins.
- The supported public baseline is provider-owned CLI auth: `claude auth status --json` for a non-mutating status read and `claude auth login --claudeai` for Claude subscription login. The app never reuses Claude Code's OAuth client ID in its own authorization request.
- `claude setup-token` is a candidate delegated flow, not accepted merely because it exists in CLI help. It ships only after a real end-to-end token is obtained, validated, stored, read after relaunch, refreshed/replaced, and deleted without the token appearing in terminal logs, app logs, diagnostics, test output, or the repository.
- A setup-token test must use a user-owned account only with explicit manual initiation. Never automate sign-out, revoke a working user credential, or print the token.
- App-owned OAuth material lives only in Keychain behind an actor. Every app-owned macOS query sets `kSecUseDataProtectionKeychain: true`, uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` because scheduled background reads are required, includes a stable account attribute, uses add-or-update rather than delete-then-add, and checks every `OSStatus`.
- `errSecInteractionNotAllowed` is retry-later, never delete. Delete treats `errSecItemNotFound` as success. No `SecItem*` call executes on `@MainActor`.
- Reading Claude Code's own credential, if retained as an explicitly chosen compatibility fallback, is read-only, user-initiated for prompting, and clearly labeled `Use Claude Code credentials`. It is not called “Agent Monitor OAuth,” and it is never silently selected after the app-owned method fails.
- The internal `/api/oauth/usage` behavior is experimental unless Anthropic documents it for third-party clients. Copy and documentation must say `Connect through Claude Code`, not claim a public Anthropic integration contract.
- Ordinary background refresh uses `.never` prompt policy. Launch, scheduled refresh, wake, activation, and passive discovery cannot open Terminal, browser, or Keychain UI.
- Existing custom `~/.claude/settings.json` content is never overwritten. Status-line installation remains a separate, non-destructive source capability.
- Disconnecting Claude removes Agent Monitor's app-owned credential and stops Agent Monitor's Claude owners; it never invokes `claude auth logout` or deletes Claude Code's credential.
- Automated coverage is limited to reproduced defects: incomplete setup-token capture/validation, background prompt leakage, delete-then-add/data-protection defects in the current self-issued store, and incoherent recovery state. Preserve the existing suite otherwise.

## Current Evidence and Boundary

- Installed Claude Code `2.1.220` exposes `claude auth login --claudeai`, `claude auth status --json`, and `claude setup-token`.
- On this machine, `claude auth status --json` returned only allowlisted fields (`loggedIn`, `authMethod`, `apiProvider`) and no secret.
- Anthropic's public Claude Code setup documentation identifies Claude subscription login as an OAuth option managed by Claude Code. Public API docs describe API keys and workload identity for the Claude API; they do not document a third-party consumer OAuth contract for Claude subscription quota.
- The repository's prior `setup-token` attempt is explicitly shelved after an inconclusive `401`; it must be re-tested with the current CLI before UI wiring.
- The current `ClaudeSelfIssuedCredentialStore` uses delete-then-add, omits `kSecUseDataProtectionKeychain`, and performs synchronous Keychain operations without actor isolation. Those are release-blocking if the app-owned credential path is revived.

Primary capability references:

- [Anthropic: Set up Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started) — Claude subscription/Console authentication is completed through Claude Code's OAuth flow.
- [Anthropic Platform authentication](https://platform.claude.com/docs/en/manage-claude/authentication) — the documented API authentication contracts are API keys and workload identity; this is not evidence of a public third-party Claude subscription OAuth contract.
- Installed `claude 2.1.220` command help captured on 2026-07-31 — exact local interfaces for `auth login --claudeai`, `auth status --json`, and `setup-token`.

## File Structure

### Create

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeAuthenticationStatus.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeAuthenticationService.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/TerminalCommandLauncher.swift` — shared, shell-quoted, visible Terminal launcher extracted from Codex.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCredentialActor.swift` — app-owned Keychain CRUD and prompt-safe borrowed read boundary.
- `docs/development/claude-auth-capability-results.md` — sanitized capability evidence and decision.

### Modify

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionState.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenService.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSelfIssuedCredentialStore.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeCredentialActions.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeUnavailableContent.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeSetupOnboardingView.swift`
- `CodexUsageMonitor/Resources/Info.plist`
- Narrow existing Claude regression test files named in the tasks below.
- `UsageProbe/README.md`, `docs/development/operating-notes.md`, `docs/product/follow-ups.md`, and `docs/product/planning-board.md`.

## Interfaces

```swift
struct ClaudeAuthenticationStatus: Equatable, Sendable {
    let loggedIn: Bool
    let method: String?
    let provider: String?
}

enum ClaudeConnectionStep: Equatable, Sendable {
    case checkingClaudeCode
    case authenticatingClaudeCode
    case obtainingAppCredential
    case requestingCredentialAccess
    case verifyingUsage
}

actor ClaudeAuthenticationService {
    func readStatus() async -> Result<ClaudeAuthenticationStatus, ClaudeAuthenticationFailure>
    func beginSubscriptionLogin() async throws
    func waitUntilLoggedIn() async throws -> ClaudeAuthenticationStatus
}

actor ClaudeCredentialActor {
    func loadAppCredential() throws -> ClaudeOAuthCredential?
    func saveAppCredential(_ credential: ClaudeOAuthCredential) throws
    func deleteAppCredential() throws
    func loadClaudeCodeCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential
}
```

`ClaudeConnectionController` consumes these interfaces and replaces the ambiguous method-only in-progress presentation with `.connecting(ClaudeConnectionStep)`. `ClaudeUsageMonitor` consumes an already-selected credential source and never decides enrollment or authorization method.

## Task 0 — Re-run the delegated OAuth capability gate

- [ ] **Step 1: Record preconditions without secrets.** Record Claude Code version, `setup-token --help`, `auth login --help`, `auth status --help`, whether a local browser can open, and whether Safari HTTPS-Only mode is enabled. Do not record account identity or credential values.
- [ ] **Step 2: Use a private, audit-owned capture channel.** Update the existing injected setup-token runner so stdout bytes remain in memory, the parser retains only the token bytes, all surrounding output is discarded, and error descriptions contain only typed cases. No shell history, temp file, pipe to `tee`, debug logging, or repository fixture may receive the real token.
- [ ] **Step 3: Manually initiate one current `claude setup-token` flow.** Complete the provider-owned browser page. If the callback is blocked, record the browser/callback failure class without pasting the callback URL or authorization code into the repository.
- [ ] **Step 4: Validate once.** Send the captured credential through the same typed usage request used in production, retain only HTTP status and decoded non-secret window/plan presence, then store it through the corrected app-owned Keychain actor.
- [ ] **Step 5: Relaunch proof.** Terminate only the audit-owned app instance, relaunch the signed build, load the app-owned item without UI, and perform one non-prompting typed usage read. Confirm the token never appears in unified logs or diagnostics.
- [ ] **Step 6: Decide by explicit gate.** Accept setup-token only if the initial validation and relaunch read both succeed and the credential can be deleted cleanly. Otherwise select the official `claude auth login --claudeai` + explicitly disclosed Claude Code credential compatibility path for this release and leave setup-token unavailable in UI.
- [ ] **Step 7: Write `docs/development/claude-auth-capability-results.md`.** Record Run / Observed / Not run, the accepted path, exact CLI version, non-secret statuses, and why the rejected path remains unavailable.

## Task 1 — Add a non-mutating Claude auth status/login service

- [ ] **Step 1: Add the reproduced status-decoding regression.** In `ClaudeConnectionControllerTests` or a new narrow test file, feed `{"loggedIn":false,"authMethod":"none","apiProvider":"firstParty"}` and a logged-in fixture; assert only allowlisted fields survive and malformed/extra secret-like fields are ignored.
- [ ] **Step 2: Implement `ClaudeAuthenticationService`.** Locate the CLI using the existing locator, run `auth status --json` with stdout capped at 16 KiB and a 15-second timeout, decode the three allowlisted fields, discard raw bytes, and map missing CLI, timeout, malformed status, and process failure distinctly.
- [ ] **Step 3: Extract `TerminalCommandLauncher`.** Move Codex's shell quoting and AppleScript execution into a shared type; keep exact executable URLs and argument arrays, never interpolate unquoted user input. Update `NSAppleEventsUsageDescription` to say Agent Monitor opens Terminal only when the user chooses a provider CLI sign-in.
- [ ] **Step 4: Implement subscription login.** Launch the exact visible command `<claude executable> auth login --claudeai`, then poll `auth status --json` every two seconds for at most five minutes. Cancellation stops polling but does not kill Terminal or sign the user out.
- [ ] **Step 5: Verify.** Run the narrow auth-service/controller regressions and both existing Codex connection tests affected by the shared Terminal launcher.

## Task 2 — Make the Claude Connect action one coherent state machine

- [ ] **Step 1: Start only after enrollment.** `connectClaude()` enables Claude enrollment, starts local activity according to its own preference, then asks `ClaudeAuthenticationService.readStatus()`.
- [ ] **Step 2: Branch on external status.** If logged in, continue to credential/usage proof. If logged out, publish `.connecting(.authenticatingClaudeCode)` and run the visible official login. If the CLI is missing, publish `.missingCLI` while keeping local activity available for the enrolled provider.
- [ ] **Step 3: Use the capability-gate winner.** For accepted setup-token, obtain/store the app-owned token, then fetch usage. For compatibility mode, show the Keychain disclosure before the first `.userInitiatedOnly` borrowed read. Never auto-fallback between methods after the user has chosen.
- [ ] **Step 4: Publish one atomic recovery result.** A successful usage proof updates connection status, plan identity, usage state, source label, and setup history in one main-actor transition. A failed proof preserves any last known usage as cached/passive but publishes one precise connection failure and one retry action; it must not require an extra ordinary refresh to recover the plan.
- [ ] **Step 5: Disconnect safely.** Cancel in-flight app work, stop Claude monitoring/local observation, delete only Agent Monitor's own credential, reset app-local selection, and leave Claude Code signed in.
- [ ] **Step 6: Add the narrow incoherent-recovery regression.** Reproduce the existing state where manual recovery restores usage without plan/connection identity; assert one successful recovery transition updates all four projections before completing.

## Task 3 — Correct the app-owned Keychain boundary

- [ ] **Step 1: Reproduce the current store defects.** Extend `ClaudeSelfIssuedCredentialStoreTests` to fail against delete-then-add, absent `kSecUseDataProtectionKeychain`, missing `kSecAttrAccount`, ignored delete/update statuses, and synchronous main-actor access.
- [ ] **Step 2: Move CRUD into `ClaudeCredentialActor`.** Build fresh query dictionaries per call. Add includes class, service `AgentUsageMonitor-ClaudeOAuth`, account `oauth-v1`, value data, explicit `AfterFirstUnlockThisDeviceOnly`, and data-protection keychain. On duplicate, update value data; never delete first.
- [ ] **Step 3: Handle every status.** Add/update/read/delete cover success, duplicate, not found, interaction not allowed, user cancellation where applicable, and an unexpected typed status. Error descriptions never contain query values or credential bytes.
- [ ] **Step 4: Remove implicit environment adoption.** `CLAUDE_CODE_OAUTH_TOKEN` cannot silently create enrollment or become the automatic production credential. If retained for a developer probe, it is command-line-probe-only and excluded from the app runtime.
- [ ] **Step 5: Clean up superseded experimental state.** On migration, best-effort delete the app-owned legacy item from the keychain implementation where the old code wrote it, then use only the versioned data-protection item. Record deletion errors without deleting a temporarily inaccessible item.
- [ ] **Step 6: Remove dead paths after the gate.** If setup-token is rejected, remove its runtime UI wiring, self-issued selection from `ClaudeCompositeCredentialStore`, and misleading browser copy while preserving only research documentation. If accepted, remove automatic borrowed-credential fallback so the selected app-owned method is explicit.
- [ ] **Step 7: Run Keychain regressions.** Tests use injected SecItem operations and never touch the real Keychain. The signed-app manual matrix performs the only real prompt/storage checks.

## Task 4 — Rewrite setup and recovery copy around the actual boundaries

- [ ] **Step 1: Unenrolled copy.** Title `Connect Claude`; body `Connect through Claude Code to show quota and local activity. The connection may ask for Keychain access.`; button `Connect Claude`.
- [ ] **Step 2: External login copy.** While Terminal/browser auth is active: `Finish signing in to Claude Code. Agent Monitor will continue when Claude Code confirms the account.`
- [ ] **Step 3: Keychain disclosure.** Before a compatibility read: `Agent Monitor will ask macOS for permission to read the Claude Code credential already stored in Keychain. It never changes or exports that credential.`
- [ ] **Step 4: Specific recovery copy.** Distinguish CLI missing, external sign-in cancelled/timed out, Keychain denied, credential absent, credential rejected, usage unavailable, passive capture absent/stale/conflicting, and custom status-line conflict. Each state has one verb-labelled retry or recovery action.
- [ ] **Step 5: Remove false claims.** Do not say the app has its own Anthropic OAuth integration unless the capability record demonstrates an accepted app-owned provider flow. Do not call CLI `/usage` proof of plan/account identity.
- [ ] **Step 6: Check wrapping and VoiceOver.** Inspect menu and Agents Settings at default dimensions, both appearances, Context Rail hidden/visible, long localized expansion, keyboard, and VoiceOver.

## Task 5 — Verification and documentation

- [ ] Run `xcodebuild` for the main macOS scheme; expected exit 0 and no new warnings.
- [ ] Run the narrow auth, Keychain, connection, monitor, and recovery regressions; expected exit 0.
- [ ] Run the full existing test suite; expected exit 0.
- [ ] Build the signed `.app` and verify resources/signature.
- [ ] Exercise: unenrolled launch; already signed-in Claude; signed-out Claude; missing CLI; setup cancel; browser callback failure; Keychain allow/deny/cancel; scheduled refresh while locked; relaunch; revoked/expired credential; passive capture only; custom status-line conflict; stale cache; disconnect/reconnect; and 20 provider switches.
- [ ] Inspect unified logs and app diagnostics for token fragments after setup, refresh, failure, and disconnect. Expected: none.
- [ ] Update `UsageProbe/README.md`, operating notes, follow-ups 9/12/13, planning board, capability results, and this plan with exact evidence and any unsupported limitation.
- [ ] Run `git diff --check`; expected exit 0.

## Security Reference Files

- `keychain-fundamentals.md` — actor isolation, exhaustive `OSStatus`, add-or-update, and macOS data-protection routing.
- `credential-storage-patterns.md` — OAuth credential lifecycle, device-only accessibility, logout cleanup, and versioned migration.

## Adapted MVVM Review Checklist

- Views call no CLI, Keychain, or network service directly.
- `ClaudeConnectionController` owns presentation transitions; `ClaudeUsageMonitor` remains the single read-cycle owner.
- Auth/status, credential storage, and usage fetching are separate injected effects.
- Every async operation is cancellable and cannot stale-overwrite a later state.
- Enrollment, external CLI login, app credential, usage availability, and plan identity are not treated as synonyms.
