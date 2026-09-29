# Claude Setup-Token Callback Reliability Implementation Plan

> **Superseded 2026-08-29:** The callback was not the final capability
> boundary. A direct CLI run proved token completion; installed CLI semantics
> and the endpoint rejection establish that it still lacks the `user:profile`
> usage scope. Preserve this document as diagnosis history and
> follow [Claude Keychain, Passive Usage, and Single-Binary Bridge](./2026-08-29-claude-keychain-statusline-single-binary.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use `systematic-debugging` and
> `diagnosing-bugs` for the live failure boundary, `swift-security-expert` for
> credential and secret handling, `swift-concurrency-pro` for process ownership
> and cancellation, `swiftui-pro` plus `writing-for-interfaces` for affected
> surfaces, and `verification-before-completion` before any completion claim.
> Use `executing-plans` to carry this out task by task.

**Goal:** Let a user complete Claude Code's email-verification/setup-token flow
without Agent Usage Monitor killing the localhost callback listener or remaining
stuck after token emission, while preserving the setup-token-first, explicit
Keychain compatibility, and manual `/usage` source policy.

**Architecture:** Claude CLI remains the sole owner of authorization, browser
handoff, localhost callback, and token exchange. An app-owned session actor owns
exactly one CLI child and PTY until token capture, explicit cancellation, launch
failure, or a long safety deadline. Only sanitized phases cross that actor. The
existing setup-token service continues to validate before storing; the
connection controller publishes connected only after validation, app-owned
Keychain persistence, selected-method activation, and monitor resumption finish.

**Tech stack:** Swift 6.2, Foundation `Process`, Darwin PTY APIs, Swift
Concurrency, Security framework, SwiftUI/Combine, `xcodebuild`, and the signed-app
build script.

## Implementation status — 2026-08-28

Production implementation is complete on `feat/claude-setup-token-primary`;
user-owned signed-app behavioral acceptance remains open. The CLI-owned
authorization deadline is now 20 minutes, token emission still ends capture
immediately, and the menu and Settings publish non-secret waiting, validating,
and saving phases with an explicit setup-only Cancel action. Attempt identity
prevents a cancelled task from publishing a late result.

The existing lock-protected process session remains the ownership boundary
instead of being rewritten as an actor: `Process` and `FileHandle` cancellation
must be callable synchronously from the task cancellation handler, and the
session already serializes those references behind `NSLock`. `Process.run()` is
synchronous and reports launch failure directly, so a separate 30-second launch
timer was not added. No automated tests were added, modified, or run. The live
callback diagnosis, same-Mac email flow, signed UI inspection, and Disconnect
defect remain with the user as documented below.

Verification evidence: `swift build --package-path CodexUsageMonitor` completed
without warnings. `Scripts/build-app.sh` completed and reported the configured
Developer ID identity, but independent `codesign --verify --deep --strict`
rejected the resulting app and both bundled executables as modified. Signing
acceptance therefore remains failed/pending; no signing settings were changed.
The repository is a raw Swift package with no Xcode project/workspace, so the
documented `xcodebuild -scheme` command reported that it had no supported project,
workspace, or package to build. No tests were added, modified, or run.

Behavioral result: the 2026-08-28 user run still failed, but not because the
owned CLI process exceeded its former deadline. Safari reported
`WebKitErrorDomain:305` and refused Claude's HTTP localhost callback because
HTTPS-Only was enabled, so the callback never reached the listener. Setup-token
is not accepted on this configuration. The explicit Claude Code Keychain method
is confirmed working. Do not replay the secret-bearing callback or disable
browser security from the app; the product priority/fallback presentation now
needs a separate decision.

Follow-up behavioral result: with Safari's HTTP warning disabled, Safari
reported completion while the app remained in the waiting phase. This proves
callback delivery and isolates the remaining boundary to CLI output capture.
The reader previously required either a delimiter after the token or process
EOF; Claude Code 2.1.247 can keep the PTY UI alive with the token at the buffer
end. Capture now drains pending bytes and accepts that trailing token only after
a 500 ms quiet period. Compile verification passes; user behavioral retest is
open.

## Product decision inherited from the competitor audit

```text
normal refresh
    fresh status-line rate_limits
        -> app-owned setup token
        -> freshest passive/cache reading

explicit recovery only
    Use Claude Code credentials…  (cross-app Keychain; may prompt)
    Force read with Claude /usage (interactive; may consume quota)
```

CodexBar and Token Monitor do not supply a better permission-free login seam.
Their reusable idea is to leave browser authentication and token refresh with
Claude CLI. Their borrowed-file/Keychain discovery and automatic `/usage`
fallbacks are deliberately not adopted.

## Constraints

- Never repeat or persist the reported callback URL. Treat its `code` and
  `state`, setup-token output, and OAuth credentials as secrets.
- Do not implement direct PKCE, reuse Claude Code's client identifier, exchange
  the callback code in this app, or open a second localhost listener.
- Do not silently read Claude Code's Keychain item when setup-token fails.
- Do not schedule `/usage` or cascade from one explicit recovery action to the
  other.
- Keep an 8 KiB maximum in-memory terminal window. Errors and diagnostics may
  contain only enum-like phases, durations, exit status categories, and Boolean
  process/listener-liveness observations.
- No new or modified automated test cases, per user direction. Preserve the
  existing tests untouched; use compile/build checks and user-owned behavioral
  acceptance.
- Keep the separately reported inert Disconnect defect out of this change. It
  remains documented and will be diagnosed independently.
- Preserve the user's existing changes in `CONTEXT.md`,
  `ClaudeCompositeCredentialStoreTests.swift`, and
  `ClaudeUsageCollectorTests.swift`.

## Task 1 — Reproduce the failure without secret-bearing diagnostics

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift`
- Modify: `docs/development/claude-auth-capability-results.md`

The flow requires a live Claude account, browser, and email verification, and
the user has reserved behavioral testing. There is therefore no agent-runnable,
deterministic red loop yet. This task creates a structured human-in-the-loop
signal; no production fix proceeds until it distinguishes the failing boundary.

- [ ] Use these ranked, falsifiable hypotheses:

  1. **The app timeout kills the listener.** Prediction: the child disappears
     near 300 seconds and the later localhost callback has no listener.
  2. **Claude CLI never binds the listener.** Prediction: the child remains alive
     but no loopback listening socket exists before the browser returns.
  3. **The browser returns on the wrong device/context.** Prediction: a listener
     exists on the Mac, but the callback is attempted somewhere that cannot
     reach that Mac's loopback interface.
  4. **Claude CLI has a callback regression.** Prediction: child and listener
     remain alive on the same Mac, but the callback does not advance CLI output.
  5. **The app misses completion after CLI success.** Prediction: the token is
     emitted or validation begins, but connection state remains signing in.

- [ ] Add a private, non-secret session phase model:

  ```swift
  enum ClaudeSetupTokenSessionPhase: Sendable {
      case launchingCLI
      case waitingForAuthorization
      case tokenCaptured
      case processExited
  }
  ```

  Detect only enough terminal structure to advance phases. Do not include a URL,
  terminal line, callback port, code, state, email, account, or token in the
  event payload.

- [ ] Record monotonic phase durations and whether the owned process is still
  running when the session completes or fails. Keep these values in memory for
  the visible failure explanation/capability record; do not write raw PTY data.
- [ ] Reproduce once in the signed app with the user: start setup-token, complete
  email verification on the same Mac, and note whether failure occurs near the
  current 300-second deadline. If the callback page fails, observe only whether
  the owned child is alive at that moment. Do not copy the URL.
- [ ] Classify the result before changing behavior:

  | Observation | Diagnosis |
  |---|---|
  | Child ended at about 300 seconds | App timeout removed the callback listener |
  | Child alive, no loopback listener | CLI listener bind/startup failure |
  | Child and listener alive, callback fails | CLI/browser/upstream callback defect |
  | Token emitted, app stays signing in | Capture/completion transition defect |

- [ ] Add the non-secret observation to the capability record. If it disproves
  the timeout hypothesis, stop and revise Tasks 2–3 before implementing them.

## Task 2 — Give the CLI callback listener a phase-aware lifetime

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenService.swift`

- [ ] Replace the single five-minute wall timer with a session policy:

  ```swift
  struct ClaudeSetupTokenSessionPolicy: Sendable {
      let launchDeadline: Duration        // 30 seconds
      let authorizationDeadline: Duration // 20 minutes after process launch
  }
  ```

  The launch deadline catches a missing or unlaunchable CLI. The authorization
  deadline starts after the process launches and accommodates email verification
  without depending on unstable prompt wording. Explicit user cancellation
  remains available throughout.

- [ ] Make `ClaudeSetupTokenCapture` own one session actor rather than racing a
  blocking `run()` call against an unconditional timer. The session actor owns
  the `Process`, PTY master, PTY slave, phase, and cancellation state.
- [ ] Start the authorization deadline after `Process.run()` succeeds. Do not
  reset it for arbitrary terminal output; noisy output must not keep the child
  alive forever.
- [ ] Keep the CLI child alive while authorization is pending. Dismissing the
  menu or opening Settings must not cancel it; explicit Cancel, app termination,
  or the active phase deadline may do so.
- [ ] Preserve the existing success boundary: once a complete
  `sk-ant-oat01-…` value and delimiter are seen, discard the terminal window,
  terminate only the owned child, reap it off `MainActor`, and return the token
  immediately without waiting for natural EOF.
- [ ] Make cleanup idempotent. Success, failure, timeout, and cancellation each
  close both descriptors once and leave no child process or localhost listener.
- [ ] Map the two deadlines to distinct non-secret internal causes, but show
  one appropriate user recovery message. No error may embed process output.

## Task 3 — Make setup progress cancellable and coherent in the UI

**Files:**

- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionState.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeSignInPresentation.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeSignInView.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeConnectionRecoveryCard.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift`

- [ ] Represent the setup-token subphase in connection state so the menu and
  Settings show factual progress: starting Claude CLI, waiting for browser/email
  verification, validating, and saving. Keep Keychain compatibility progress
  separate.
- [ ] While waiting, say that verification must be completed in a browser on the
  same Mac and that it can take several minutes. Keep the surface compact under
  the existing native-menu height guardrail.
- [ ] Add **Cancel Claude setup** while a setup-token task is active. It calls a
  controller cancellation method that awaits capture cleanup and returns to a
  retryable disconnected state.
- [ ] Do not add a callback-URL paste field in this change. Claude Code 2.1.247
  documents no such input; add it only after a separate live capability result
  proves the CLI accepts it and a secret-safe input design is approved.
- [ ] On capture success, advance through validation and storage without briefly
  returning to disconnected. Publish `.connected` only after all of these are
  true:

  1. `/api/oauth/usage` accepted the captured token;
  2. the App-Owned Claude Credential round-tripped through its Keychain actor;
  3. `.setupToken` is the active selected method;
  4. Claude enrollment and monitor reading are resumed.

- [ ] If validation, storage, or activation fails, clear the in-flight task,
  remove any incomplete app-owned state, and publish one retryable, stage-specific
  failure. Never fall through to borrowed credentials or `/usage`.

## Task 4 — Keep the existing source hierarchy explicit in documentation

**Files:**

- Modify: `docs/development/authentication-and-usage-collection.md`
- Modify: `docs/development/operating-notes.md`
- Modify: `UsageProbe/README.md`
- Modify: `docs/development/claude-auth-capability-results.md`
- Modify: `docs/product/follow-ups.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-08-26-claude-setup-token-primary-and-recovery.md`

- [ ] Link the competitor crosswalk in the source audit as the canonical answer
  to “how do CodexBar and Token Monitor do this?”
- [ ] Mark this plan as the focused successor to the old plan's five-minute
  timeout requirement; do not rewrite the historical implementation record.
- [ ] Document same-Mac email verification, the longer authorization window,
  explicit cancellation, and specific timeout recovery.
- [ ] Keep the two unresolved defects separate: this plan owns setup-token
  callback reliability; Disconnect remains open and unchanged.
- [ ] Update the capability record with the exact Claude CLI version, signed app
  build, behavior observed, and remaining unverified matrix. Record no secrets.

## Task 5 — Compile, build the signed app, and hand behavioral acceptance to the user

- [ ] Run the main macOS build without changing signing or build settings:

  ```bash
  cd CodexUsageMonitor
  xcodebuild -scheme CodexUsageMonitor \
    -destination 'platform=macOS' \
    -derivedDataPath /tmp/AgentUsageMonitor-ClaudeCallback build
  ```

- [ ] Build the signed application:

  ```bash
  ./Scripts/build-app.sh
  ```

- [ ] Do not add, modify, or stage test files. Report existing dirty test files
  as preserved user changes.
- [ ] Hand the signed app to the user for this behavioral matrix:

  1. standard browser authorization;
  2. email verification completed in under five minutes;
  3. email verification completed after more than five minutes;
  4. Cancel while waiting, then retry;
  5. successful validation followed by quit/relaunch and an authoritative read;
  6. callback or browser failure produces a retryable state, not permanent
     signing-in;
  7. no Keychain prompt on normal setup-token reads;
  8. explicit borrowed-credential and forced `/usage` actions remain separate;
  9. Disconnect is still recorded as a known, separately scoped defect.

- [ ] Inspect the actual signed menu and affected Claude Settings state at the
  default window/popover sizes in Light and Dark mode. If automation cannot
  complete the external browser/email flow, state that limitation and do not
  claim behavioral success.
- [ ] Search the staged diff and app-owned diagnostics/export for unexpected
  concrete callback values, token values beyond the allowlisted literal prefix,
  and raw setup output. Expected: no secret material.

## Completion criteria

- Email verification may exceed five minutes without losing the CLI-owned
  localhost listener.
- Setup always ends as connected, a specific retryable failure, or an explicit
  cancellation; it never remains indefinitely signing in.
- The app-owned token remains the primary authoritative source after one setup.
- Passive status-line, borrowed Keychain compatibility, and forced `/usage`
  preserve their existing explicit boundaries.
- No callback URL, authorization code/state, token, or raw PTY transcript is
  logged, persisted, exported, or included in diagnostics.
- Signed-app behavioral acceptance is recorded honestly; the unrelated
  Disconnect defect remains open.
