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

## Why not a self-run OAuth flow

The [July spike](2026-07-21-claude-oauth-web-login-spike-findings.md) got an authorize response only by sending **Claude Code's own public `client_id`**. Rejected here for three independent reasons: the delegated-OAuth plan forbids reusing that client ID; the consent screen would name Claude Code while a different application receives the token, which misrepresents the grant to the user at the exact moment they authorize it; and it would require this app to run its own `/v1/oauth/token` exchange, which the shipped design has never done. It is also unproven — the exchange itself was never observed, having been IP-throttled at 429.

`claude setup-token` has Claude Code run its own flow under its own identity and hand back a token meant to be given to another tool. Truthful consent, no impersonation, no exchange of ours.

---

## Decision requiring your sign-off

**Should method B mirror Claude Code's token into our own Keychain item after a successful user-initiated read?**

It sounds like it would fix everything — read once with a prompt, then read our own copy forever. **My recommendation is no**, for two reasons:

1. **It does not actually work.** Claude Code rotates that token frequently (`mdat` moves constantly). A mirrored copy goes stale within hours, returns 401, and we are back at the borrowed item needing a fresh read — the prompt is postponed, not removed.
2. **It costs a privacy commitment for that non-fix.** The README, the app's Data & Privacy page, and the release notes all currently state that the app reads Claude Code's credential and never copies it. Mirroring makes those statements false and requires changing all three.

The durable answer to the same desire is method A, which gets a token that is genuinely ours. If you disagree, say so and I will design the mirroring path with the disclosure changes it requires.

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
- **Compilation is not acceptance.** Every prompt-behaviour claim requires the signed app; unit tests can only prove which policy was requested, not what macOS did.
