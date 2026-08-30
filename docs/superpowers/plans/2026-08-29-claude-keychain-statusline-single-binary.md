# Claude Keychain, Passive Usage, and Single-Binary Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Use `swift-security-expert` for every credential or Keychain change, `swift-concurrency-pro` and `swift-architecture-skill` for actor/process ownership, `swiftui-pro` and `writing-for-interfaces` for menu and Settings changes, `systematic-debugging` for the delegated-renewal and single-binary capability gates, and `verification-before-completion` before any completion claim. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the disproven `claude setup-token` quota path with a fresh status-line fast path plus explicitly authorized Claude Code Keychain OAuth, preserve manual `/usage` recovery, and ship one compiled/signed executable in the app bundle while keeping Claude usage collection unattended after enrollment.

**Architecture:** Keep the existing MVVM ownership: `QuotaViewModel` owns user intents and presentation state, `ClaudeConnectionController` owns one Claude Code credential enrollment transaction, `ClaudeUsageMonitor` owns cadence, and `ClaudeUsageCollector` owns source ordering. A fresh field-scoped status-line snapshot returns before credential access; otherwise the collector performs a non-prompting read of Claude Code's existing Keychain credential and calls the usage endpoint, then falls back to the freshest local snapshot/cache. The main executable gains an early, synchronous bridge mode. An app-owned symlink under the legacy stable `claude-usage-bridge` filename targets that executable inside its signed bundle.

**Tech Stack:** Swift 6.2, SwiftUI and Combine on macOS 14+, Foundation `Process` and `FileHandle`, Security and LocalAuthentication for read-only cross-app Keychain access, Swift Package Manager, `ClaudeUsageBridgeCore`, and the repository's signed-app packaging script.

## Implementation Status — through 2026-08-30

Implemented on `feat/claude-setup-token-primary`. The user reported that the
signed-app smoke test now appears to work; the detailed behavioral and visual
matrix below was not itemized and remains open. Production compilation succeeds. The setup-token route,
method selection, app-owned credential store, and separate bridge product were
removed. **Connect Claude** now enrolls safe passive capture and validates Claude
Code's existing Keychain credential; Disconnect immediately clears app-local
state and exact managed artifacts. The signed main executable supplies early
bridge mode through a stable Application Support symlink.

The planned copied-main capability gate failed as designed: strict `codesign`
verification reported an invalid Info.plist when the executable was removed
from its bundle. The selected symlink preserves the valid bundle-bound signature,
one Mach-O, the stable basename contract, and rollback replacement path. A signed
symlink probe validated successfully, wrote only allowlisted fields, exited in
0.01 seconds, and left no matching process.

No automated tests were authored or run during the final implementation, per
user direction. The authorized simplification pass deleted suites coupled only
to retired setup-token and old connection contracts, removed one broad
feature-presence case, and mechanically reconciled surviving credential fixtures;
the test target was deliberately not compiled. Remaining evidence is the
signed-app build/package audit, headless bridge probe, and user behavior matrix.
Scheduled delegated renewal remains disabled because its capability gate is not
proven.

Implementation evidence recorded on 2026-08-29:

- `swift build --package-path CodexUsageMonitor --product CodexUsageMonitor` exited 0.
- The macOS `CodexUsageMonitor` scheme built with `xcodebuild` and exited 0.
- `Scripts/build-app.sh` produced an app and the signing command returned 0. A
  controlled probe found that every bundle-file hash remained identical over
  12 seconds, but later strict verification alternated between valid and
  invalid without a byte change. The local user Keychain search list contains
  the login Keychain repeated many times, and code-signing identity enumeration
  did not return a stable valid result. Treat durable Developer ID verification
  as a local signing-environment blocker, not as a proven bundle mutation. The
  script now accepts the configured identity only after an immediate strict
  bundle verification and otherwise emits its existing ad-hoc/ACL-durability
  warning.
- Follow-up verification on 2026-08-30 rebuilt the macOS scheme and release app
  successfully. The app is signed by `Developer ID Application: David Wang
  (C4CSB67T4J)` with hardened runtime; `codesign --verify --deep --strict` reports
  it valid and satisfying its designated requirement. Gatekeeper rejects this
  local artifact only as `Unnotarized Developer ID`. The scheme build warned that
  multiple macOS destinations matched, and `actool` emitted CoreMedia/AVFCore
  symbol warnings while still producing the asset catalog.
- Bundle inspection found exactly one Mach-O:
  `Contents/MacOS/CodexUsageMonitor`.
- A strict-signature-verified stable-basename symlink processed a sanitized
  payload in 0.15 seconds, used about 6.1 MB maximum resident set (2.77 MB peak
  footprint), wrote only the two rate-limit windows/schema/capture time, and
  left no matching process. Source inspection found no sleep-assertion API.
- `Scripts/verify-signed-app-resources.sh` remains blocked by an unrelated
  existing catalog/verifier mismatch: the current catalog contains `AppIcon`,
  onboarding assets, and `CodexMenuBar`, while the script expects `Codex`,
  `Claude`, and `Copilot`. This implementation did not alter asset sources or
  claim that check passed.
- Automated tests were not run. Signed UI, Keychain prompt, relaunch,
  lock/sleep, and the full Connect/Disconnect matrix remain for user acceptance.
- User-reported observation: the signed-app smoke test “seems to be working.”
  No narrower state-by-state claim is inferred from that report.

The decisive capability result is now known: Claude Code 2.1.247 completed
`claude setup-token`, printed a one-year token, and exited 0, ruling out browser
callback and token emission as the final blocker. Claude Code's installed
setup-token semantics, the usage endpoint's scope rejection, and matching
Anthropic issue reports establish that this inference credential does not carry
the `user:profile` scope required by `GET /api/oauth/usage`. The feature's
callback/capture repairs cannot correct a scope the provider did not issue.

The working user-observed path is Claude Code's existing Keychain credential. The source-pinned competitor audit agrees: CodexBar and the reviewed token-monitor apps use provider-created credential state, delegated Claude CLI refresh, status-line `rate_limits`, and/or an explicit `/usage` command. None exposes a hidden permission-free OAuth contract that this app can reproduce.

## Global Constraints

- “No user input” means **unattended steady state after one informed enrollment action**. A first-run zero-input guarantee is impossible: the app cannot silently authenticate a Claude account, choose macOS's **Always Allow** Keychain decision, or modify `~/.claude/settings.json` without prior consent.
- The enrollment action must disclose both effects before they happen: read Claude Code's OAuth credential from Keychain, and install/repair Agent Monitor's privacy-scoped status line only when no unrelated working status line would be replaced.
- Automatic refreshes use `KeychainPromptPolicy.never`. They fail closed to status-line/cache and never raise a Keychain dialog.
- The app never stores, mirrors, refreshes directly, logs, prints, diagnoses, or exports Claude Code's token. It exists only in memory for the request that needs it.
- Do not revive `claude setup-token`, accept `CLAUDE_CODE_OAUTH_TOKEN`, read `.credentials.json` as an undisclosed fallback, shell out to `security` as a prompt workaround, or implement direct PKCE with Claude Code's client identity.
- `/usage` remains a separate, explicit, cost-disclosed recovery action. It is never scheduled or cascaded from an OAuth failure.
- A working third-party Claude status line is never replaced. A project-owned command may be repaired automatically only after the app has a durable record of the user's management consent.
- Preserve the status-line privacy boundary: parse only `rate_limits.five_hour` and `rate_limits.seven_day`; never retain prompts, responses, model names, paths, session identifiers, or other payload fields.
- Bridge mode must return before constructing SwiftUI scenes, `NSApplication`, `ApplicationDelegate`, `QuotaViewModel`, monitoring actors, notification state, Keychain readers, or network clients.
- Target one **compiled and signed executable artifact in the app bundle**. The chosen stable-path design links to that executable from Application Support; it does not build, copy, or sign a second program.
- Preserve the user's existing test edits. Do not reset, checkout, stash, or overwrite unrelated changes.
- Per user direction, do not author, maintain, or run automated test cases in this implementation. Production compilation, package/signature checks, sanitized command probes, and power/process measurements belong to the implementer; behavioral and visual acceptance belongs to the user.
- Follow `docs/development/public-update-workflow.md`. Work on a dedicated branch, do not push without approval, and never create the GitHub pull request; the user submits it manually.

---

## Accepted Source Policy

```text
automatic Claude refresh
    |
    +-- fresh status-line rate_limits (< 2 minutes)
    |       `-- serve immediately; no secret, Keychain, network, or CLI
    |
    +-- Claude Code Keychain credential
    |       +-- read with interaction forbidden
    |       +-- GET /api/oauth/usage once
    |       `-- on proven expiry, attempt only the capability-approved
    |           throttled Claude CLI renewal and retry once
    |
    +-- freshest older status-line snapshot or cached OAuth result
    `-- unavailable with a specific recovery action

explicit user actions only
    +-- Connect Claude: allow one Keychain prompt and enroll passive capture
    +-- Reconnect Claude: repeat the user-initiated Keychain validation
    +-- Force Read: run Claude /usage after its separate cost disclosure
    `-- Disconnect: stop app-owned monitoring and remove app-owned artifacts
```

The status-line result is first because it is both fresh and access-free. The Keychain result is the authoritative on-demand source because it includes the account plan and full usage response. “Primary” refers to the authoritative credential, not permission to skip a fresher passive snapshot.

## Competitor Answer Applied to This App

| Observed technique | What it actually requires | Agent Monitor implementation |
|---|---|---|
| CodexBar OAuth | CodexBar cache, Claude credential file, or Claude Code Keychain | Claude Code Keychain only; no copied app cache of the secret |
| CodexBar login | `claude auth login --claudeai` in a PTY | Recovery guidance to sign into Claude Code; no app-owned OAuth impersonation |
| Token Monitor renewal | `claude auth status --json` or a heavier PTY command | Capability-gated delegated renewal, fingerprinted through non-secret Keychain attributes |
| Token Monitor `/usage` | Interactive or PTY-driven Claude command | Existing manual **Force Read** action only |
| Claude token monitor status line | `rate_limits` supplied on stdin | Existing `ClaudeUsageBridgeCore`, invoked through main-executable bridge mode |
| `claude setup-token` monitors | Long-lived inference token | Rejected for quota because it lacks `user:profile` |

## Single-Binary Decision

| Option | One bundle Mach-O | Stable across app moves/updates | 0.0.1 rollback | Decision |
|---|---:|---:|---:|---|
| Invoke `Contents/MacOS/CodexUsageMonitor --claude-usage-bridge` directly | Yes | No; the configured absolute path changes | Poor; old app does not understand the flag | Reject as primary |
| Copy the already-signed main executable to `Application Support/CodexUsageMonitor/ClaudeBridge/claude-usage-bridge` and dispatch by basename | Yes | Yes | Yes | Rejected: bundle-bound signature becomes invalid |
| Atomically symlink the stable Application Support basename to the signed bundle executable | Yes | In-place updates retain the target; app launch repairs moves | Yes; 0.0.1 can replace the same path | **Selected after signature gate** |
| Remove passive capture | Yes | N/A | N/A | Reject; discards the only verified zero-secret source |

The selected route preserves the current command contract:

```text
'~/Library/Application Support/CodexUsageMonitor/ClaudeBridge/claude-usage-bridge' --quiet
```

The stable symlink resolves to the signed executable inside the app bundle. Early dispatch recognizes either the `claude-usage-bridge` basename or an explicit `--claude-usage-bridge` diagnostic flag. The stable basename is required for rollback compatibility: the already-published helper accepts `--quiet`, while it would reject a new bridge-mode flag.

## Architecture Fit and Ownership

- Keep MVVM. This migration reduces credential methods and processes; it does not justify a new state-management framework.
- `ClaudeKeychainCredentialStore` is an actor and the only owner of secret-bearing `SecItemCopyMatching` calls. It performs no writes.
- `ClaudeLegacySetupTokenCleanup` is a small actor that can delete only the app-owned service/account created by the failed feature. Its failure never blocks Connect or Disconnect.
- `ClaudeConnectionController` owns one connection attempt, publishes one coherent state, and has no setup-token progress/cancellation branch.
- `ClaudeUsageCollector` owns source ranking, endpoint backoff, and a maximum of one post-renewal retry.
- `ClaudeDelegatedRefreshCoordinator` owns single-flight/cooldown behavior and discards all CLI output. It is enabled for scheduled recovery only if Task 3 proves the selected command renews an actually expired credential without a browser, prompt, turn charge, or account mutation.
- `ClaudeStatusLineInstaller` owns the stable executable symlink, the exact managed command, consent metadata, non-destructive settings merge, and uninstall.
- `ClaudeUsageBridgeCommand` owns synchronous stdin/argument/stdout/exit behavior and delegates all parsing/writing to `ClaudeUsageBridgeCore`.
- The custom process entry point is the only owner of the decision to enter GUI or bridge mode.

## File Map

### Create

- `CodexUsageMonitor/Sources/CodexUsageMonitor/AgentUsageMonitorEntryPoint.swift` — custom `@main` dispatcher that enters bridge mode before SwiftUI lifecycle creation.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/ClaudeUsageBridgeCommand.swift` — synchronous bridge argument/stdin/stdout/exit adapter around `ClaudeUsageBridgeCore`.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeLegacySetupTokenCleanup.swift` — idempotent deletion of only the app-owned obsolete token item and preference.
- `docs/adr/0002-claude-usage-auth-and-bridge-boundaries.md` — durable source, consent, renewal, and single-binary decision.

### Delete after migration gates pass

- `CodexUsageMonitor/Sources/ClaudeUsageBridge/main.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenAvailability.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenProgress.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenService.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSelfIssuedCredentialStore.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCredentialSelectionStore.swift`

### Modify

- `CodexUsageMonitor/Package.swift` — make the app target depend on `ClaudeUsageBridgeCore`; remove the separate bridge product/target.
- `CodexUsageMonitor/Scripts/build-app.sh` — stop copying/signing nested code; sign and verify the app once.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift` — remove `@main` and CLI-mode branching from SwiftUI initialization.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift` — keep one actor-isolated borrowed provider and explicit prompt policy.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionController.swift` — one Claude Code credentials transaction and app-local disconnect.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeConnectionState.swift` and `ClaudeConnectionStatus.swift` — remove setup-token methods/progress and use factual connection states.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeDelegatedRefresh.swift` — capability-approved scheduled policy, single flight, cooldown, timeout, output discard, and fingerprint proof.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift` — remove multi-method routing while preserving scope preflight and typed errors.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift` — status line → Keychain OAuth → capability-approved renewal/retry → freshest local result.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageProbeCommand.swift` — direct borrowed-store construction and factual source output.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — simplified dependency graph, enrollment transaction, passive management, and non-blocking disconnect cleanup.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeCredentialActions.swift`, `ClaudeConnectionRecoveryCard.swift`, `ClaudeSignInPresentation.swift`, `ClaudeSignInView.swift`, `ClaudeMenuContent.swift`, and `ClaudeUnavailableContent.swift` — one connection method and recovery copy.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeSetupOnboardingView.swift`, `ClaudeAgentSettingsView.swift`, and `AgentsSettingsView.swift` — one disclosed enrollment action and existing shared Settings layout.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift` — atomically link the stable bridge path to the signed main executable, manage consent, and migrate/uninstall exact project-owned commands.
- `UsageProbe/README.md`, `docs/development/authentication-and-usage-collection.md`, `docs/development/claude-auth-capability-results.md`, `docs/development/claude-usage-monitor-source-audit-2026-08-26.md`, `docs/development/operating-notes.md`, `docs/product/follow-ups.md`, and `docs/product/planning-board.md` — replace the disproven setup-token policy and record verification limits.

### Preserved compatibility boundary

- `CodexUsageMonitor/Tests/**` — no test authoring or maintenance is authorized in this implementation; pre-existing edits remain intact and the resulting compile limitation is recorded rather than hidden.
- `CONTEXT.md` — preserve the user's glossary work while reconciling its Claude credential term with the accepted source policy.
- Signing identity, entitlements, bundle identifier, deployment target, notification policy, refresh cadence, and unrelated provider code.

---

## Task 0 — Preserve the dirty branch and establish the implementation boundary

- [x] Read `AGENTS.md`, `docs/development/public-update-workflow.md`, this plan, the source audit, capability results, Keychain durability record, and Product Follow-ups 10 and 12 before editing.
- [x] Record but do not alter the current working tree:

  ```bash
  git status --short --branch
  git diff --stat
  git diff -- CodexUsageMonitor/Tests CONTEXT.md
  ```

  Expected: branch `feat/claude-setup-token-primary`; production/docs changes from the failed setup-token work plus user-owned test and `CONTEXT.md` edits are visible.

- [x] Follow the public update workflow and use the approved implementation branch without destructive cleanup.
- [x] Record a pre-change production build only:

  ```bash
  swift build --package-path CodexUsageMonitor --product CodexUsageMonitor
  ```

  Expected: exit 0. Do not run `swift test`.

- [x] Mark the two setup-token plans as superseded by this plan; do not erase their historical diagnosis.

## Task 1 — Replace the setup-token model with one borrowed credential boundary

### Step 1.1: Simplify the domain and controller

- [x] Remove `.setupToken`, setup progress, capture timeouts, cancellation, app-owned credential routing, and selected-method fallback from the connection model.
- [x] Replace `case signingIn(ClaudeSignInMethod)` with the factual `case connecting`; retain typed failures.
- [x] Make `ClaudeConnectionController.connect()` run exactly one operation: a user-initiated borrowed-Keychain read followed by one successful `/api/oauth/usage` response. Publish `.connected` only after both succeed.
- [x] Keep the Keychain prompt policy explicit at the call site:

  ```swift
  // ❌ Never allow a scheduled read to inherit an interactive default.
  try await source.fetch()

  // ✅ Connect may prompt; every background reason forbids interaction.
  try await source.fetch(promptPolicy: .userInitiatedOnly)
  try await source.fetch(promptPolicy: .never)
  ```

- [x] Remove persisted credential-method selection. There is one OAuth credential source, so enrollment state is sufficient non-secret policy.

### Step 1.2: Preserve the cross-app Keychain security boundary

- [x] Keep `ClaudeKeychainCredentialStore` actor-isolated. No `SecItem*` call belongs on `@MainActor`.
- [x] For `.never`, use a non-interactive `LAContext` and map Keychain failures without exposing credential data.
- [x] Retain the provider-compatible read-only query and document that Agent Monitor never migrates or rewrites another application's item.
- [x] Preserve the `user:profile` preflight before the network request. A missing scope is a definitive reconnect/source failure, not a reason to attempt setup-token.
- [x] Keep credential bytes non-`Codable`, non-printable, memory-only, and scoped to the request.

### Step 1.3: Migrate and clean only app-owned obsolete state

- [x] Add `ClaudeLegacySetupTokenCleanup` with the exact service/account `AgentUsageMonitor-ClaudeOAuth` / `setup-token-v1`, data-protection routing, and idempotent delete semantics.
- [x] Treat success and not-found as complete; cleanup failure never blocks app state.
- [x] Remove `claude.credential-method.v1` without reading or printing the obsolete token.
- [x] Run cleanup after launch and again as best effort during Disconnect. Delete the obsolete setup-token production sources after compilation no longer references them.

### Step 1.4: Fix Disconnect as part of ownership simplification

- [x] Disconnect first clears app-local enrollment and stops monitors, then removes app-owned cache/snapshot/status-line artifacts. It never deletes or modifies `Claude Code-credentials` or signs Claude Code out.
- [x] Obsolete-token cleanup and file deletion are independent best-effort operations. One failure cannot prevent the button from changing the visible state to disconnected.
- [ ] If removing a managed status-line entry fails, show that specific residual-artifact warning in Settings while leaving the provider disconnected. This residual warning remains a follow-up.

### Step 1.5: Compile checkpoint

  ```bash
  swift build --package-path CodexUsageMonitor --product CodexUsageMonitor
  rg -n "setupToken|SetupToken|setup-token" CodexUsageMonitor/Sources/CodexUsageMonitor
  ```

  Expected: build exits 0. Source search returns only the narrowly named legacy cleanup comments/constants, or no results. No test command is run.

## Task 2 — Make one informed Connect action produce an unattended steady state

- [x] Rename the primary action to **Connect Claude**. Before the button, use concise copy:

  > Reads Claude Code's OAuth credential from Keychain. macOS may ask once. Choose Always Allow for unattended refreshes.

- [x] Add a second sentence to the same enrollment disclosure:

  > If Claude Code has no custom status line, Agent Monitor also installs a privacy-scoped usage capture.

- [x] On the explicit button action, enable Claude enrollment, inspect passive-capture state, and start the user-initiated Keychain validation. Do not install or read anything merely because the onboarding view appeared.
- [x] When status line is absent, install it under this action's consent. Preserve a foreign working status line and continue with Keychain OAuth.
- [x] Persist only a non-secret managed-capture flag after successful installation/migration. Once set, app launches may atomically repair only the exact command Agent Monitor owns.
- [x] If the user chooses **Allow** rather than **Always Allow**, Connect may succeed for that read, but later automatic reads fail closed to passive/cache. Recovery copy explains the next action without repeatedly prompting.
- [x] Keep the existing recovery-card geometry: when OAuth needs attention, recovery replaces the quota card instead of stacking below it.
- [x] Use shared Settings components and wrapping callout copy; do not introduce `Form`, unbounded controls, caption-sized recovery text, or new geometry constants outside `SettingsLayoutMetrics`.
- [x] Compile the production product. Light/Dark, small-screen, keyboard, VoiceOver, prompt, and detailed Disconnect behavior remain in the user's signed-app matrix.

## Task 3 — Prove or reject unattended Claude CLI renewal

This is a capability gate, not an assumption. The current implementation calls a coordinator with `.scheduled` while the coordinator refuses every non-user reason, so it cannot close an expired-token outage.

- [ ] Preserve the non-secret Keychain modification-date fingerprint: query attributes only, never `kSecReturnData`.
- [ ] During a naturally or safely observed expired-token window, run `claude auth status --json` with stdout/stderr discarded and a 15-second timeout. Record only command outcome, elapsed time, and whether the fingerprint changed.
- [ ] If the fingerprint changes, retry `/api/oauth/usage` once with `.never`. Accept renewal only if that retry returns 200.
- [ ] If `auth status` does not renew, evaluate the competitor-style PTY `/status` command separately. Determine whether it consumes a turn, opens UI/browser, prompts, mutates account state, or emits identity. Do not enable it automatically unless all side-effect gates pass.
- [ ] Approve scheduled delegated renewal only when all are true:

  - no browser, Keychain prompt, terminal window, or user interaction;
  - no Claude turn/quota charge;
  - all output is discarded and no identity reaches diagnostics;
  - fingerprint changes only when renewal is due;
  - one post-renewal `/api/oauth/usage` retry succeeds;
  - single-flight, five-minute cooldown, 15-second timeout, and one retry prevent loops.

- [ ] If no command passes, keep delegated renewal user-initiated and state the product limit: unattended reads continue through fresh status-line data and cache, but authoritative OAuth can require reconnect after provider-token expiry.
- [ ] Do not treat process exit 0 by itself as renewal evidence.

## Task 4 — Add main-executable bridge mode without removing the helper yet

### Step 4.1: Introduce the early entry point

- [x] Add `ClaudeUsageBridgeCore` as a dependency of the main executable target, then remove the old helper target after the bridge gate.
- [x] Remove `@main` from `CodexUsageMonitorApp`. Move command dispatch ahead of the SwiftUI composition root so CLI modes do not instantiate it.
- [x] Add a custom entry point with this shape:

  ```swift
  @main
  enum AgentUsageMonitorEntryPoint {
      static func main() {
          if ClaudeUsageBridgeCommand.shouldRun(
              arguments: CommandLine.arguments,
              executableName: URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
          ) {
              exit(ClaudeUsageBridgeCommand.run(arguments: CommandLine.arguments))
          }
          CodexUsageMonitorApp.main()
      }
  }
  ```

- [x] `shouldRun` returns true for executable basename `claude-usage-bridge` or the explicit diagnostic flag `--claude-usage-bridge`. It evaluates before accessing `NSApplication.shared` or creating a Task.
- [x] Move the existing helper's argument/stdin/stdout behavior without changing its command contract.

### Step 4.2: Compare old and new process behavior

- [x] Compare the old helper contract with the main-executable bridge using sanitized payloads and isolated output paths.
- [x] Attempt the copied-main signature gate; strict validation failed because the executable's signature is bound to the app Info.plist. Select and probe the signed-bundle symlink instead; it showed no GUI and left no persistent process.
- [x] Verify the candidate before using it:

  ```bash
  codesign --verify --strict --verbose=2 /path/to/copied/claude-usage-bridge
  codesign -dv --verbose=4 /path/to/copied/claude-usage-bridge
  ```

  Result: copied-main verification failed because the signature is bound to the
  bundle Info.plist. Verification through the selected symlink succeeds and
  retains the main app executable's designated identifier.

### Step 4.3: Power and sleep gate

- [ ] Measure 30 invocations of the old helper and copied-main bridge on the same signed release build using `/usr/bin/time -l`; record median/p95 elapsed time and maximum resident set size without retaining payload contents.
- [ ] Before and after a 100-invocation run, inspect `pmset -g assertions`. Bridge invocations must create no persistent `PreventUserIdleSystemSleep`, `PreventSystemSleep`, audio, network, or background-task assertion.
- [x] Inspect process lifetime for the sanitized probe: it exited after stdin EOF and left no child or matching process.
- [ ] Accept the unified bridge only if copied-main bridge median is at most 150 ms, p95 at most 300 ms, maximum RSS at most 40 MB, no persistent assertion/process appears, and snapshot semantics are unchanged. If it misses a threshold, stop before deleting the helper and present the measurements to the user; reliability/status-line capture outranks packaging simplification.

## Task 5 — Migrate the stable bridge path and remove the second build target

- [x] Replace the rejected copied-main design with an atomic stable symlink to `Bundle.main.executableURL`; set owner-only directory permissions and validate the signed source and staged link before replacement.
- [x] If link creation, permissions, or signature validation fails, leave `settings.json` untouched.
- [x] Keep the configured command exactly compatible with 0.0.1: stable path plus `--quiet`, with no new mandatory flag.
- [x] On upgrade, replace only exact Agent Monitor commands. Preserve foreign status lines. Record management consent so later app moves/updates repair the symlink without recurring input.
- [x] On rollback to 0.0.1, the older app can replace the same stable basename with its helper and its existing `--quiet` command continues to work. The ADR records why basename dispatch is retained.
- [x] Remove the `claude-usage-bridge` product, `ClaudeUsageBridge` executable target, and `Sources/ClaudeUsageBridge/main.swift`. Keep `ClaudeUsageBridgeCore` as a library target used by the app.
- [x] Remove nested helper copy/signing from `build-app.sh`. Sign the app once; do not add a second signing identity or entitlement.
- [x] Confirm the app bundle contains only one executable Mach-O:

  ```bash
  find CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents -type f -perm -111 -print
  file CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents/MacOS/CodexUsageMonitor
  ```

  Expected: only `Contents/MacOS/CodexUsageMonitor` is executable in the bundle.

## Task 6 — Reconcile UI, errors, and disconnect behavior

- [x] Remove setup-token buttons, progress, cancellation, error copy, and the “use setup token instead” recovery branch from menu, onboarding, and Settings.
- [x] Use these action labels consistently: **Connect Claude**, **Reconnect Claude**, **Disconnect**, **Set Up Passive Capture**, **Repair Passive Capture**, and **Force Read**.
- [x] Make failures specific:

  - Keychain item missing: “Sign in to Claude Code, then reconnect.”
  - access denied/non-interactive failure: “Reconnect and choose Always Allow for unattended refreshes.”
  - insufficient scope: “Claude Code's current credential cannot read usage. Sign in to Claude Code again.”
  - endpoint/backoff: show the last reading and next eligible time.
  - passive capture conflict: “Claude Code already has a custom status line. Agent Monitor left it unchanged.”

- [x] Disconnect changes visible state immediately, stops quota and local-activity owners, removes exact app-managed status-line configuration and snapshots/cache, and leaves Claude Code signed in.
- [x] Preserve the recovery-over-quota layout, native controls, shared Settings rows, intrinsic provider height, and existing menu hit targets.
- [ ] Do not claim the full UI matrix fixed until the user performs the signed-app prompt, Connect, Refresh, Disconnect, small-screen, Light/Dark, keyboard, and VoiceOver pass. The user-reported smoke test is recorded without expanding its scope.

## Task 7 — Update durable documentation and supersede false claims

- [x] Add ADR 0002 with these decisions and alternatives: no first-run zero-input guarantee; status-line first; borrowed Keychain authoritative; no token copy; setup-token rejected by scope; delegated renewal capability-gated; copied-main rejected in favor of a stable signed-bundle symlink; `/usage` manual.
- [x] Correct Source Audit finding F4 and its policy table. Preserve the original date/evidence but add the 2026-08-29 scope result and links to the two public Anthropic issue reports already documented by the investigation.
- [x] Update the capability record with the user's exact safe evidence: CLI 2.1.247 completed setup-token, emitted a redacted token, exited 0, and that token cannot satisfy `user:profile`. Never add the token, callback code/state, email, or raw response.
- [x] Mark the setup-token primary and callback-reliability plans superseded, not completed.
- [x] Merge Product Follow-ups 10 and 12 under this plan's implementation status; keep the separate visual Disconnect acceptance item visible until the user verifies it.
- [x] Update the planning board entries for Claude local analytics, single-binary capture, first-run setup, and source durability to point here.
- [x] Update `UsageProbe/README.md`, authentication/usage collection, and operating notes with the actual source order, one-time consent boundary, stable symlink bridge path, rollback behavior, and known renewal limit.
- [x] Preserve and reconcile the user's `CONTEXT.md` glossary changes with the accepted Claude credential boundary.

## Task 8 — Build, signature, privacy, and user-owned acceptance handoff

### Implementer-owned non-behavioral verification

- [x] Compile production source:

  ```bash
  swift build --package-path CodexUsageMonitor --product CodexUsageMonitor
  ```

- [x] Build the signed `.app` using `CodexUsageMonitor/Scripts/build-app.sh`; also build the Swift-package-generated macOS scheme with `xcodebuild`.
- [x] Verify packaging:

  ```bash
  codesign --verify --deep --strict --verbose=2 CodexUsageMonitor/.build/CodexUsageMonitor.app
  spctl --assess --type execute --verbose=4 CodexUsageMonitor/.build/CodexUsageMonitor.app
  find CodexUsageMonitor/.build/CodexUsageMonitor.app/Contents -type f -perm -111 -print
  ```

- [x] Invoke the installed Application Support bridge with sanitized JSON; inspect the owner-only snapshot permissions and confirm the output contains only allowlisted fields.
- [x] Search the production tree and built binary for removed setup-token UI/commands and accidental credential logging. Do not inspect or print real Keychain data.
- [x] Record compiler warnings, signature/notarization limitations, power metrics, the unmaintained test-compilation boundary, and every unobserved behavior in this plan and handoff.

### User-owned signed-app behavioral matrix

- [ ] First Connect with no prior Keychain grant; observe **Allow / Always Allow / Deny** behavior.
- [ ] Relaunch and scheduled refresh after **Always Allow**; confirm no recurring dialog.
- [ ] Fresh status-line snapshot while Keychain access is unavailable; confirm it is served first.
- [ ] Existing custom status line; confirm no overwrite.
- [ ] App-managed legacy status line; approve migration once, then move/update/relaunch the app and confirm capture continues.
- [ ] Disconnect; confirm the UI changes immediately, monitoring stops, app-owned snapshots/command are removed, and Claude Code remains signed in.
- [ ] Expired borrowed credential; confirm only the capability-approved renewal behavior occurs.
- [ ] Force Read; confirm separate cost disclosure and no implication that it connected the OAuth account.
- [ ] Inspect affected menu and Settings states in Light/Dark, at the default/small-screen size, with pointer, keyboard, and VoiceOver.
- [ ] Sleep/wake and an extended ordinary-use period; confirm no unexpected wake, sleep prevention, prompt, terminal/browser launch, or persistent bridge process.

## Completion Criteria

- [x] `claude setup-token` is absent from production behavior and described only as superseded evidence/cleanup.
- [ ] One informed Connect action can establish Keychain OAuth and passive capture without later recurring prompts when the user chooses **Always Allow**.
- [x] Fresh status-line usage is implemented without token or Keychain access.
- [x] Automatic Keychain reads forbid prompts; failures degrade to the freshest local reading with a specific recovery action.
- [x] `/usage` remains manual and cost-disclosed.
- [x] The app bundle contains one executable Mach-O; the stable Application Support bridge is a verified symlink to that signed main executable, not a separately built target.
- [x] Bridge mode initializes no GUI/runtime owners; the observed sanitized one-shot probe exited after stdin EOF with no child or matching process and preserved field-scoped atomic snapshots. The 30-invocation cost measurement, 100-invocation assertion inspection, and longer repeated power/sleep matrix remain unobserved.
- [x] Disconnect is implemented as app-local and immediate and never changes Claude Code's credential/session; the user reported a successful smoke test without itemizing this state.
- [x] Production compilation and app packaging exit 0. The 2026-08-30 artifact
  passes strict Developer ID signature verification and contains one executable;
  Gatekeeper rejects it only because this local build is not notarized.
  Behavioral/visual results are reported only from the user's signed-app pass.

## Explicit Non-Goals

- A hidden or independent Anthropic OAuth client.
- Guaranteed first-run usage with literally zero consent or account state.
- Copying Claude credentials into Agent Monitor's Keychain.
- Reading credential files as a silent fallback.
- Scheduling `/usage` or an unproven PTY command.
- Removing status-line capture merely to obtain one executable.
- Adding or updating automated tests in this implementation.

## Reference Files

- `swift-security-expert/SKILL.md` — Keychain isolation, `OSStatus`, data-protection, and secret-handling invariants.
- `swift-security-expert/references/keychain-fundamentals.md` — non-main-thread `SecItem` access, non-interactive errors, query specificity, and Keychain performance.
- `swift-security-expert/references/credential-storage-patterns.md` — OAuth credential lifecycle, no plaintext/copying, logout cleanup, and actor ownership.
- `swift-architecture-skill` references — retain the repository's MVVM composition and explicit effect owners rather than introducing a new framework.
- `swift-concurrency-pro` references — actor isolation, single-flight tasks, cancellation, and process timeout ownership.
- `swiftui-pro/SKILL.md` — native SwiftUI structure, data flow, accessibility, and performance constraints.
- `writing-for-interfaces/SKILL.md` — factual, actionable connection, permission, recovery, and destructive-action copy.
