# Claude Prompt-Free Credentials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `swift-security-expert` for every Keychain and credential change, `systematic-debugging` for the capability gate, and `writing-for-interfaces` for each user-facing state. Steps use checkbox (`- [ ]`) syntax. **This plan is awaiting the maintainer's verification. Do not write code against it until it is approved.**

**Goal:** After a user connects Claude once — by either method — Agent Monitor never surprises them with a macOS Keychain dialog again.

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
- The passive status-line tier is **dead in production** — `ClaudeStatusLineInstaller` has no call site — so today there is no silent degrade path for P3/P4 to use.

**Consequence for design:** P3 and P4 both require a working passive tier. [Task 2 of the durability plan](2026-08-12-claude-usage-source-durability.md#task-2--revive-the-passive-status-line-tier-as-a-first-class-keychain-free-source) is therefore a hard prerequisite of this plan, not a parallel nicety.

## How comparable projects fetch Claude usage

Reviewed 2026-08-13 by reading the sources at `main` of the two neighbouring projects already recorded in [RESOURCES.md](../../../RESOURCES.md). This changes the plan's conclusions, so it is recorded before them.

### Both agree with our tier-1 contract

| | CodexBar (Swift, macOS menu bar) | Token Monitor (Electron, cross-platform) |
|---|---|---|
| Usage endpoint | `GET https://api.anthropic.com/api/oauth/usage` | same constant |
| Headers | Bearer, `anthropic-beta`, `claude-code` User-Agent | same |
| Credential source | Claude Code's Keychain item | `~/.claude/.credentials.json` first, Keychain second |
| macOS Keychain read | Security framework | spawns `security find-generic-password -s "Claude Code-credentials" -w` |
| Windows | — | `wincred` via `advapi32` |
| Own token refresh | **Yes** — `POST https://platform.claude.com/v1/oauth/token` | **Yes** — `POST https://console.anthropic.com/v1/oauth/token` |
| Client ID | `9d1c250a-…` (Claude Code's public client, env-overridable) | `9d1c250a-…` (same, hard-coded) |

Our endpoint, headers, and credential shape match both independent implementations, so tier 1 is not where our divergence lies.

### CodexBar tried the `security` CLI read and turned it off

`ClaudeOAuthCredentials+SecurityCLIReader.swift` implements the same `security` CLI read Token Monitor relies on, behind a `.securityCLIExperimental` strategy. It is **force-disabled**: `ClaudeOAuthKeychainReadStrategyPreference.current()` coerces `.securityCLIExperimental` back to `.securityFramework`, so even an explicitly stored preference cannot select it. Their own note gives the reason — `security` can prompt too.

**Consequence for us:** shelling out to `security` is not a way around the ACL, and a comparable project has already paid to learn that. Do not spend a task on it.

### CodexBar treats the Keychain prompt as a first-class, gated event

It carries `ClaudeOAuthKeychainAccessGate`, `KeychainPromptMode`, `KeychainPreAlertGate`, `DirectKeychainReadConsent`, and `KeychainQueryTiming` — a **pre-alert shown before the system dialog**, an explicit consent record, and prompt-mode gating. That is the same shape as this plan's prompt contract, arrived at independently, which is corroboration that *bounding* the prompt is the realistic goal for a borrowed credential rather than eliminating it. It also carries `ClaudeOAuthUsageRateLimitGate`, the counterpart of our 429 back-off.

### CodexBar has a third option we had not considered: delegated refresh

`ClaudeOAuthDelegatedRefreshCoordinator` exchanges nothing. It **touches the Claude CLI so Claude Code refreshes its own token**, then confirms success by observing the Keychain item's fingerprint change. It carries cooldowns (5 min default, 20 s after a soft failure), in-flight joining so concurrent callers share one attempt, and prompt-policy gating.

This needs no client ID, no exchange, and no impersonation — and it deliberately causes exactly the credential rewrite our Task 0 sampler waited four and a half hours to observe naturally and never saw.

## The token-exchange question, reopened

The [July spike](2026-07-21-claude-oauth-web-login-spike-findings.md) was shelved after the exchange returned persistent 429s and was never once observed succeeding. The review above shows the approach is not infeasible — **two shipping projects perform it** — so "unproven" described our single attempt, not the method.

**A distinction the earlier analysis missed, and it matters.** Both projects use the **`refresh_token` grant**, starting from a refresh token Claude Code already obtained and stored. Neither runs an authorize step. Our spike was blocked on the **`authorization_code` grant** — the initial exchange following a browser consent screen. Different requests, different objections:

- The consent-screen objection — "the screen would name Claude Code while a different app receives the token" — applies **only to the authorization step**. A refresh-token exchange opens no browser and shows no consent screen, so that objection does not carry over. The earlier draft of this plan applied it to both. That was wrong.
- The delegated-OAuth constraint is written as "never reuses Claude Code's OAuth client ID **in its own authorization request**". Refreshing a token Claude Code already holds is arguably not an authorization request. That is a judgement call for the maintainer, and this plan should not quietly decide it either way.
- What a refresh **does not** do is make the credential ours. It extends a borrowed one, so it does not deliver P5 and does not remove the Keychain read. Its real value is against **D5** (the expiring borrowed token) and independence from whether Claude Code has run recently.

`claude setup-token` remains the only route to a genuinely app-owned credential and therefore the only route to P5, so it stays as Task 1 — but it is no longer presented as the sole survivor of a field of rejected options. Task 1b re-tests what was never actually tried.

---

## Decision requiring your sign-off

**Should method B mirror Claude Code's token into our own Keychain item after a successful user-initiated read?**

It sounds like it would fix everything — read once with a prompt, then read our own copy forever. **My recommendation is no**, for two reasons:

1. **It does not actually work.** Claude Code rotates that token frequently (`mdat` moves constantly). A mirrored copy goes stale within hours, returns 401, and we are back at the borrowed item needing a fresh read — the prompt is postponed, not removed.
2. **It costs a privacy commitment for that non-fix.** The README, the app's Data & Privacy page, and the release notes all currently state that the app reads Claude Code's credential and never copies it. Mirroring makes those statements false and requires changing all three.

The durable answer to the same desire is method A, which gets a token that is genuinely ours. Task 1b's delegated refresh is the cheaper partial answer: it keeps the credential where it is and lets Claude Code renew it, which addresses the staleness that mirroring was reaching for without copying anything. If you disagree, say so and I will design the mirroring path with the disclosure changes it requires.

---

## Architecture

**Fit — no new architecture.** `ClaudeUsageCollector` remains the tier owner and `ClaudeUsageMonitor` the read-cycle owner. What changes is credential ownership and who is allowed to prompt.

```
                        ┌─ Method A: app-owned item ──── our ACL ──── never prompts (P5)
 ClaudeCredentialActor ─┤
                        └─ Method B: Claude Code item ── their ACL ─── prompts only on P2
                                        │
                                        └── on lapse ──► passive tier ──► cache   (P4)
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

- [ ] **Step 1: Re-run the capability gate** from [the delegated OAuth plan](2026-07-31-claude-delegated-oauth-and-setup.md#task-0--re-run-the-delegated-oauth-capability-gate) against Claude Code **2.1.227**. That plan's evidence is 2.1.220; the interface is still present, so nothing blocks the re-test. The repository's prior attempt ended in an inconclusive 401 and is treated as **unreproduced**, not as a verdict.
- [ ] **Step 2: Capture the token without letting it reach disk.** `setup-token` is interactive, so the runner needs a PTY, an in-memory-only buffer, a parser retaining **only** the token bytes, and typed errors carrying no captured text. No shell history, temp file, `tee`, log, diagnostics field, or fixture may receive it.
- [ ] **Step 3: Validate once, then prove it survives relaunch.** One typed usage request; retain only HTTP status and non-secret window presence. Store it, terminate the app, relaunch, and perform one **non-prompting** read. That read succeeding is the direct proof of P5.
- [ ] **Step 4: Decide by explicit gate.** Accept only if validation, relaunch read, and clean deletion all succeed. Otherwise leave method A unavailable in the UI and record why.
- [ ] **Step 5: Write the capability record** — Run / Observed / Not run, accepted path, exact CLI version, non-secret statuses, and why any rejected path stays unavailable.

## Task 1b — Re-test the token exchange instead of shelving it

The July spike is **not** removed. It was one attempt against one host that never returned anything but 429, which is not a verdict. Two shipping projects perform this exchange, so the question is which variant works here.

Run these in order and stop at the first that succeeds — each is cheaper and less contested than the one after it.

- [x] **Step 1: Delegated refresh first — no exchange at all.** **Implemented 2026-08-13.** `ClaudeDelegatedRefreshCoordinator` touches the CLI on a 401 and proves renewal by the credential's modification date changing; 10 regressions. Its stdout is discarded because it carries `email`/`orgId`/`orgName`. **Renewal efficacy is unverified** — the touch runs cleanly but has not yet been observed against an expired token; CodexBar's PTY `claude /status` is the documented fallback if `auth status` proves insufficient. Original step text: Reproduce CodexBar's approach: touch the Claude CLI so **Claude Code** refreshes its own token, then confirm by observing the Keychain item's `mdat`/fingerprint change. No client ID, no token endpoint, no impersonation, and nothing this repository's constraints prohibit. Carry over their hard-won details: a cooldown (5 min default, ~20 s after a soft failure), in-flight joining so concurrent callers share one attempt, and never touching from a non-user-initiated path without the cooldown.
  - This doubles as the **Task 0 experiment we could not run**: a deliberate credential rewrite, immediately followed by a non-prompting read. If the grant dies exactly there, the recurring-prompt cause is identified in one shot.
- [ ] **Step 2: Retry the `refresh_token` exchange against the untried host.** Our spike only ever hit `console.anthropic.com/v1/oauth/token`. CodexBar uses `platform.claude.com/v1/oauth/token`. Send **one** `POST`, form-encoded, `grant_type=refresh_token` + `refresh_token` + `client_id`, using the refresh token already in Claude Code's Keychain item.
  - **One attempt only.** The spike established that retrying re-arms the cooldown; treat a 429 as "wait much longer", never as "try again shortly". Record status only.
  - A 200 here answers a question open since July. A 429 or 4xx is also an answer — record which, and stop.
- [ ] **Step 3: Only if both fail, revisit the `authorization_code` flow.** This is the one carrying the real consent-screen objection, because the browser page would name Claude Code while this app receives the token. Do not run it without an explicit decision recorded against the delegated-OAuth plan's client-ID constraint.
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
- [ ] **Step 2: Implement P3 — check passive freshness first.** On an explicit refresh under method B, if a passive snapshot newer than a short threshold exists, serve it and **do not read the Keychain at all**. The cheapest way to not prompt is to not read.
- [ ] **Step 3: Implement P2 — one prompt per press.** A single user action performs at most one prompting read; internal retries, degrades, and the composite store's second method must not each get their own dialog.
- [ ] **Step 4: Implement P4 — silent degrade with a labelled recovery.** On `errSecInteractionNotAllowed` or a lapsed grant, fall to passive/cache, mark the reading's source honestly, and surface one `Reconnect` action. No dialog, no modal, no silent blank.
- [ ] **Step 5: Add `ClaudePromptBudgetTests`.** Drive every refresh reason through an injected Keychain spy and assert the exact number of prompting reads: zero for launch/scheduled/wake/menu-open; at most one per user action; zero when a fresh passive snapshot exists; zero after method A is configured.

## Task 4 — Make the choice explicit and honest

- [ ] **Step 1: Present both methods with their real trade-off.** Method A: "Set up a token for Agent Monitor — macOS will not ask again." Method B: "Use the credential Claude Code already stored — macOS will ask permission, and may ask again if it withdraws access." Do not describe method B as permanent.
- [ ] **Step 2: Disclose before the first borrowed read**, not after: what is read, that it is never changed or exported, and that a dialog is about to appear.
- [ ] **Step 3: Never auto-switch methods.** A failure of the chosen method degrades **visibly** through `ClaudeEffectiveMethodRecorder`; the app does not quietly start using the other one.
- [ ] **Step 4: Distinguish the failure states** — CLI missing, setup cancelled or timed out, Keychain denied, credential absent, credential rejected, usage unavailable, passive capture absent or stale. Each gets one verb-labelled action.
- [ ] **Step 5: Handle method A revocation.** A long-lived token has no refresh, so a 401 means "reconnect" and must be reported as such, not retried indefinitely.

## Task 5 — Verification

- [ ] `swift build` — exit 0, no new warnings; `swift test` — exit 0.
- [ ] `ClaudePromptBudgetTests` — P1–P5 asserted.
- [ ] Build the signed `.app` **with the Developer ID identity** and verify signature and stapling. An ad-hoc rebuild changes the designated requirement and destroys the existing grant — it would manufacture the exact bug being fixed.
- [ ] Signed-app matrix: method A setup, relaunch, and a full poll interval with **zero** dialogs; method B allow, deny, and cancel; grant lapse mid-session; passive-only operation; expired credential; disconnect and reconnect; 20 provider switches.
- [ ] Leave the app running across at least one full "few hours" window and confirm no dialog appears outside an explicit press.
- [ ] Inspect unified logs and diagnostics for token fragments after setup, refresh, failure, and disconnect. Expected: none.
- [ ] `git diff --check` — exit 0; `gitleaks git . --log-opts='origin/main..HEAD' --redact=100` — no findings.

## Risks and limitations

- **The lapse cause is still unknown.** This plan is deliberately designed not to need the answer: method A removes the cross-app read, and P1–P4 bound method B's behaviour either way. Task 0's sampler continues independently.
- **Method A depends on an ungated interface.** If the capability gate rejects `setup-token`, P5 is unavailable this release and the honest outcome is P1–P4 plus a working passive tier. That limitation must then be stated in the README, Data & Privacy page, and release notes rather than left implied.
- **P3 and P4 require the passive tier**, which is currently dead. Durability-plan Task 2 must land first or these degrade to "silent, but with no data".
- **The exchange question is open, not closed.** Task 1b re-tests what the July spike never actually reached. A working refresh would not deliver P5; it extends a borrowed credential rather than creating an app-owned one.
- **Compilation is not acceptance.** Every prompt-behaviour claim requires the signed app; unit tests can only prove which policy was requested, not what macOS did.
