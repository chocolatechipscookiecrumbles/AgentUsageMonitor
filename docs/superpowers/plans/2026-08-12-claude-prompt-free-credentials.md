# Claude Prompt-Free Credentials Implementation Plan

> **Execution note (2026-08-26):** This document remains the research record and prompt-contract source. The consolidated, task-ordered implementation sequence is now [Claude Setup-Token Primary and Explicit Recovery](2026-08-26-claude-setup-token-primary-and-recovery.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use `swift-security-expert` for every Keychain and credential change, `systematic-debugging` for the capability gate, and `writing-for-interfaces` for each user-facing state. Steps use checkbox (`- [ ]`) syntax. **Direction approved 2026-08-26: app-owned `setup-token` credential for normal authoritative reads, explicit `/usage` recovery, and borrowed Keychain access only as an opt-in compatibility mode. Production enrollment remains gated on Tasks 1 and 2.**

**Goal:** After a user connects Claude once, normal operation uses passive Claude status-line data plus an app-owned credential and never needs access to Claude Code's Keychain item.

**Branch:** `feat/claude-prompt-free-credentials`. The read-path defects are a separate, independently shippable change on `fix/claude-refresh-defects`, implementing [Task 1 of the durability plan](2026-08-12-claude-usage-source-durability.md#task-1--make-an-explicit-refresh-always-perform-a-real-read). Neither branch depends on the other.

---

## The honest version of the goal

The requested outcome is "never prompt again after login". One of the two sign-in methods can deliver that as a guarantee; the other cannot, and the difference is not a matter of effort.

**Method A — app-owned token (`claude setup-token`): a real guarantee.** The token lives in an item **this app creates**. Our own reads of our own item never consult a cross-app ACL, so there is no dialog to raise and nothing that can be revoked out from under us. Zero prompts after setup, by construction.

**Method B — borrowed Claude Code credential: not ours to guarantee.** The ACL belongs to *Claude Code's* Keychain item. macOS decides whether our read is still trusted, and we cannot write, refresh, or repair that decision from our process. Any plan claiming "never prompts again" for method B would be claiming authority over something the app does not own. What we *can* guarantee is a strict prompt budget, below.

So the plan does both: it makes method A available so a user can opt into a genuinely prompt-free setup, and it makes method B's prompting **bounded, predictable, and never spontaneous** for users who stay on it.

## The prompt contract

These are the acceptance criteria. Each is verifiable, and each holds regardless of what Task 0 eventually concludes about why the grant lapses.

| # | Guarantee | Applies to |
|---|---|---|
| P1 | No scheduled, launch, wake, activation, or menu-open read can **ever** raise a dialog. Enforced by `kSecUseAuthenticationUIFail` on every non-user-initiated read. | Both methods |
| P2 | A dialog may appear **only** as the direct result of a button the user just pressed, and at most **once** per press. | Method B |
| P3 | If a fresh passive reading is available, an explicit refresh **serves it without touching the Keychain at all** — no read, so no dialog. | Method B |
| P4 | When the grant lapses, the app **degrades silently** to the passive tier or cache and shows a labelled `Reconnect` action. It never opens a dialog to tell the user something is wrong. | Method B |
| P5 | After completing method A setup, **no Keychain dialog is possible** for ordinary operation, because no cross-app item is read. | Method A |
| P6 | The user is told, before choosing, which method prompts and which does not. | Both |

P1–P4 convert the current experience — a dialog reappearing at unpredictable intervals — into one that only ever appears when the user asked for something. P5 removes it entirely for anyone who opts in.

---

## Evidence this rests on

From [claude-keychain-grant-durability.md](../../development/claude-keychain-grant-durability.md):

- The grant is **live in the steady state** for both prompting and non-prompting reads; the failure is a transition that has not yet been caught.
- Ruled out: ad-hoc signing (the build is Developer ID signed with a stable requirement), a second app identity, and item recreation (`cdat` static since 2026-07-20 while `mdat` advances).
- Claude Code **updates its item in place**, frequently.
- The passive status-line tier was historically dead in production. The installer and repair UI are now wired, and a real `claude-rate-limits.json` snapshot has been observed. Signed-app acceptance with tier 1 deliberately unavailable is still open.

**Consequence for design:** P3 and P4 both require a working passive tier. [Task 2 of the durability plan](2026-08-12-claude-usage-source-durability.md#task-2--revive-the-passive-status-line-tier-as-a-first-class-keychain-free-source) is therefore a hard prerequisite of this plan, not a parallel nicety.

## 2026-08-26 source audit and decision

The expanded, revision-pinned audit is recorded in [claude-usage-monitor-source-audit-2026-08-26.md](../../development/claude-usage-monitor-source-audit-2026-08-26.md). Its central correction is that CodexBar and the reviewed Token Monitor projects are not actually access-free: they read a credential file or Keychain item, keep an app-owned Keychain cache, or delegate to Claude CLI.

The only verified zero-secret source is Claude Code's documented status-line `rate_limits` payload. It is event-driven rather than a guaranteed on-demand read. The selected order is therefore:

1. Fresh passive status-line snapshot, with no credential access.
2. App-owned long-lived token created through `claude setup-token`, for normal authoritative reads.
3. Cache, labelled with its age and source.
4. Explicit recovery: `Force read with Claude /usage`.
5. Separately disclosed compatibility mode: `Use Claude Code credentials`, which may prompt and is never an automatic fallback.

### Why direct PKCE is not the primary login

Current ecosystem examples reuse Claude Code's public client identifier and private/undocumented endpoints. That is not an independent Agent Usage Monitor OAuth registration: the browser identifies Claude Code while this app receives the result. The repository's own authorization-code spike also never completed because the token exchange returned 429. Do not ship this path unless Anthropic publishes a third-party contract or issues this app its own client registration.

### Why `security` is not a workaround

Shelling out to `/usr/bin/security` still asks macOS to read Claude Code's Keychain item. It can prompt and does not bypass the item's access control. It remains prohibited as a supposed prompt-free mechanism.

### Why `setup-token` is the primary credential

Claude Code 2.1.241 exposes `setup-token` as a long-lived token flow for subscription users. Claude Code owns the browser interaction; Agent Usage Monitor receives an app-specific secret and stores it in an item the app owns. This avoids the recurring cross-app ACL problem. It is not a refresh-token session: a rejected or revoked token must surface `Reconnect`.

### Borrowed credentials remain compatibility-only

CodexBar's prompt gates and delegated refresh remain useful evidence for users who explicitly choose borrowed credentials. They do not make the credential app-owned and cannot guarantee prompt-free access. The composite store must not silently switch to this method after an app-owned-token failure.

The prior question about mirroring Claude Code's credential is closed: do not mirror it. Rotation makes the copy stale and copying would violate current privacy disclosures without removing the eventual fallback read.

## Architecture

**Fit — no new architecture.** `ClaudeUsageCollector` remains the tier owner and `ClaudeUsageMonitor` the read-cycle owner. What changes is credential ownership and who is allowed to prompt.

```
fresh status-line snapshot ──► serve without credential access
             │ stale/absent
             ▼
app-owned setup-token item ──► authoritative usage read ──► cache
             │ unavailable/rejected
             ▼
explicit recovery ──► Claude /usage
                  └─► borrowed Claude Code credential (compatibility opt-in only)
```

## File Structure

### Create
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCredentialActor.swift` — all Keychain CRUD, off the main actor.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeSetupTokenCapture.swift` — PTY-backed, in-memory-only token capture.
- `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudePromptBudgetTests.swift` — P1–P4 as executable assertions.
- `docs/development/claude-auth-capability-results.md` — the Task 1 gate record.

### Modify
- `Connection/ClaudeSelfIssuedCredentialStore.swift`, `ClaudeCompositeCredentialStore.swift`, `ClaudeOAuthCredential.swift`, `ClaudeConnectionController.swift`, `ClaudeSetupTokenService.swift`
- `Quota/ClaudeOAuthUsageSource.swift`, `ClaudeUsageCollector.swift`
- `Settings/ClaudeAgentSettingsView.swift`, `ClaudeSetupOnboardingView.swift`
- `Menu/ClaudeCredentialActions.swift`, `ClaudeConnectionRecoveryCard.swift`
- README, Data & Privacy page, operating notes, follow-ups 9/12, planning board

---

## Task 1 — Gate `claude setup-token` before building any UI on it

- [ ] **Step 1: Re-run the capability gate** from [the delegated OAuth plan](2026-07-31-claude-delegated-oauth-and-setup.md#task-0--re-run-the-delegated-oauth-capability-gate) against Claude Code **2.1.241**. The command still advertises `setup-token`; the repository's prior attempt ended in an inconclusive 401 and is treated as **unreproduced**, not as a verdict.
- [ ] **Step 2: Capture the token without letting it reach disk.** `setup-token` is interactive, so the runner needs a PTY, an in-memory-only buffer, a parser retaining **only** the token bytes, and typed errors carrying no captured text. No shell history, temp file, `tee`, log, diagnostics field, or fixture may receive it.
- [ ] **Step 3: Validate once, then prove it survives relaunch.** One typed usage request; retain only HTTP status and non-secret window presence. Store it, terminate the app, relaunch, and perform one **non-prompting** read. That read succeeding is the direct proof of P5.
- [ ] **Step 4: Decide by explicit gate.** Accept only if validation, relaunch read, and clean deletion all succeed. Otherwise leave method A unavailable in the UI and record why.
- [ ] **Step 5: Write the capability record** — Run / Observed / Not run, accepted path, exact CLI version, non-secret statuses, and why any rejected path stays unavailable.

## Task 1b — Keep borrowed-credential renewal compatibility-only

This task cannot become the primary login. It exists only to make the explicitly
selected borrowed-Keychain compatibility mode less fragile.

- [x] **Step 1: Delegated refresh first — no exchange at all.** **Implemented 2026-08-13.** `ClaudeDelegatedRefreshCoordinator` touches the CLI on a 401 and proves renewal by the credential's modification date changing; 10 regressions. Its stdout is discarded because it carries `email`/`orgId`/`orgName`. **Renewal efficacy is unverified** — the touch runs cleanly but has not yet been observed against an expired token; CodexBar's PTY `claude /status` is the documented fallback if `auth status` proves insufficient. Original step text: Reproduce CodexBar's approach: touch the Claude CLI so **Claude Code** refreshes its own token, then confirm by observing the Keychain item's `mdat`/fingerprint change. No client ID, no token endpoint, no impersonation, and nothing this repository's constraints prohibit. Carry over their hard-won details: a cooldown (5 min default, ~20 s after a soft failure), in-flight joining so concurrent callers share one attempt, and never touching from a non-user-initiated path without the cooldown.
  - This doubles as the **Task 0 experiment we could not run**: a deliberate credential rewrite, immediately followed by a non-prompting read. If the grant dies exactly there, the recurring-prompt cause is identified in one shot.
- [ ] **Step 2: If delegated refresh proves ineffective against an expired borrowed token, run one evidence-only `refresh_token` request against the untried host.** Our spike only ever hit `console.anthropic.com/v1/oauth/token`; CodexBar uses `platform.claude.com/v1/oauth/token`. This experiment may inform compatibility mode but must not be wired into app-owned enrollment.
  - **One attempt only.** The spike established that retrying re-arms the cooldown; treat a 429 as "wait much longer", never as "try again shortly". Record status only.
  - A 200 here answers a question open since July. A 429 or 4xx is also an answer — record which, and stop.
- [x] **Step 3: Reject the direct `authorization_code` flow for production.** **Decision recorded 2026-08-26.** The browser would name Claude Code while Agent Usage Monitor receives the token, the endpoints are not a published third-party contract, and the local exchange never completed. Reconsider only if Anthropic publishes a supported third-party flow or issues this app its own client registration.
- [ ] **Step 4: Record the outcome as evidence, not as a recommendation.** Extend the spike findings document with Run / Observed / Not run for each step: exact host, grant type, HTTP status, and whether the Keychain item changed. No token, refresh token, authorization code, or callback URL may appear — the spike's own security note is the standard to meet.
- [ ] **Step 5: State what it does and does not buy.** A working refresh extends a **borrowed** credential. It helps D5 and removes the dependency on Claude Code having run recently. It does **not** deliver P5 and does not remove the Keychain read, and the plan must not imply otherwise.

## Task 2 — Correct the app-owned Keychain boundary

The existing store is not fit to hold a primary credential.

- [ ] **Step 1: Reproduce the defects.** Extend the store's tests to fail against: delete-then-add, absent `kSecUseDataProtectionKeychain`, missing stable `kSecAttrAccount`, ignored delete/update statuses, and synchronous main-actor access.
- [ ] **Step 2: Move CRUD into `ClaudeCredentialActor`.** Fresh query dictionaries per call; service `AgentUsageMonitor-ClaudeOAuth`, account `oauth-v1`; **add-or-update, never delete-first**; `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so scheduled reads work while the screen is locked; no `SecItem*` call on `@MainActor`.
- [ ] **Step 3: Handle every `OSStatus`.** Success, duplicate, not found, interaction-not-allowed, user-cancelled, and an unexpected typed status. `errSecInteractionNotAllowed` is **retry-later and never a reason to delete**. Error descriptions never contain query values or credential bytes.
- [ ] **Step 4: Remove implicit environment adoption.** `CLAUDE_CODE_OAUTH_TOKEN` is honoured at *read* time today, so a stray variable can silently become the production credential and mask which method is serving. Restrict it to the command-line probe or remove it.
- [ ] **Step 5: Migrate and clean up.** Best-effort delete of the superseded legacy item, then use only the versioned data-protection item. Record a deletion error rather than deleting an item that is merely temporarily inaccessible.
- [ ] **Step 6: Keychain regressions** run against injected `SecItem` operations and never touch the real Keychain.

## Task 3 — Enforce the prompt contract in code

- [ ] **Step 1: Make P1 structurally impossible to violate.** The prompt policy must be derived from the refresh reason at a single choke point, with no call site able to pass `.userInitiatedOnly` on a non-user-initiated path. Add the assertion as a test, not a comment.
- [x] **Step 2: Implement P3 — check passive freshness first.** **Implemented 2026-08-26.** A valid status-line snapshot captured within two minutes is served before OAuth for every refresh reason, and the regression proves the credential provider is not invoked.
- [ ] **Step 3: Implement P2 — one prompt per press.** A single user action performs at most one prompting read; internal retries, degrades, and the composite store's second method must not each get their own dialog.
- [ ] **Step 4: Implement P4 — silent degrade with a labelled recovery.** On `errSecInteractionNotAllowed` or a lapsed grant, fall to passive/cache, mark the reading's source honestly, and surface one `Reconnect` action. No dialog, no modal, no silent blank.
- [ ] **Step 5: Add `ClaudePromptBudgetTests`.** Drive every refresh reason through an injected Keychain spy and assert the exact number of prompting reads: zero for launch/scheduled/wake/menu-open; at most one per user action; zero when a fresh passive snapshot exists; zero after method A is configured.

## Task 4 — Make the choice explicit and honest

- [ ] **Step 1: Present both methods with their real trade-off.** Method A: "Set up a token for Agent Monitor — macOS will not ask again." Method B: "Use the credential Claude Code already stored — macOS will ask permission, and may ask again if it withdraws access." Do not describe method B as permanent.
- [ ] **Step 2: Disclose before the first borrowed read**, not after: what is read, that it is never changed or exported, and that a dialog is about to appear.
- [x] **Step 3: Never auto-switch methods.** **Implemented 2026-08-26.** `ClaudeCompositeCredentialStore` invokes only the selected provider; regressions prove a missing app-owned credential never reads the borrowed provider.
- [ ] **Step 4: Distinguish the failure states** — CLI missing, setup cancelled or timed out, Keychain denied, credential absent, credential rejected, usage unavailable, passive capture absent or stale. Each gets one verb-labelled action.
- [ ] **Step 5: Handle method A revocation.** A long-lived token has no refresh, so a 401 means "reconnect" and must be reported as such, not retried indefinitely.
- [x] **Step 6: Keep `/usage` as explicit recovery.** `ClaudeCLIUsageProbe` and its `QuotaViewModel` call site already run only after user consent and never join scheduled collection. Preserve this boundary while changing the credential order.

## Task 5 — Verification

- [ ] `swift build` — exit 0, no new warnings; `swift test` — exit 0.
- [ ] `ClaudePromptBudgetTests` — P1–P5 asserted.
- [ ] Build the signed `.app` **with the Developer ID identity** and verify signature and stapling. An ad-hoc rebuild changes the designated requirement and destroys the existing grant — it would manufacture the exact bug being fixed.
- [ ] Signed-app matrix: method A setup, relaunch, and a full poll interval with **zero** dialogs; method B allow, deny, and cancel; grant lapse mid-session; passive-only operation; expired credential; disconnect and reconnect; 20 provider switches.
- [ ] Leave the app running across at least one full "few hours" window and confirm no dialog appears outside an explicit press.
- [ ] Inspect unified logs and diagnostics for token fragments after setup, refresh, failure, and disconnect. Expected: none.
- [ ] `git diff --check` — exit 0; `gitleaks git . --log-opts='origin/main..HEAD' --redact=100` — no findings.

### Verification evidence — 2026-08-26 partial implementation

- The passive-first and no-cross-method-fallback regressions were observed red
  against the prior behavior, then green after the minimal changes.
- `ClaudeCollectorPromptPolicyTests`: 5 tests, 0 failures.
- `ClaudeCompositeCredentialStoreTests`: 10 tests, 0 failures.
- `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS'
  -derivedDataPath /tmp/agent-usage-claude-oauth-derived build`: exit 0,
  `BUILD SUCCEEDED`; Xcode emitted only its multiple-matching-destinations warning.
- Full `swift test`: 370 tests executed, 1 skipped, 1 failure. The reproducible
  failure is the pre-existing timing assertion
  `ClaudeUsageMonitorTests.testReconnectResumesReading`; neither its source nor
  its test was changed in this slice. Do not mark the full-suite checkbox until
  that independently scoped failure is resolved.
- `git diff --check`: exit 0.
- `claude setup-token` was not executed, so no secret was generated or exposed.
  The interactive capability/relaunch and signed-app prompt matrix remain open.

## Risks and limitations

- **The lapse cause is still unknown.** This plan is deliberately designed not to need the answer: method A removes the cross-app read, and P1–P4 bound method B's behaviour either way. Task 0's sampler continues independently.
- **Method A depends on an ungated interface.** If the capability gate rejects `setup-token`, P5 is unavailable this release and the honest outcome is P1–P4 plus a working passive tier. That limitation must then be stated in the README, Data & Privacy page, and release notes rather than left implied.
- **P3 and P4 require the passive tier.** Installation/repair and real snapshot production now work; signed-app proof with OAuth deliberately unavailable remains open.
- **Borrowed refresh research cannot become primary auth.** Task 1b may improve the explicitly selected compatibility mode, but it never creates an app-owned credential and does not deliver P5.
- **Compilation is not acceptance.** Every prompt-behaviour claim requires the signed app; unit tests can only prove which policy was requested, not what macOS did.
