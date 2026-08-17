# Claude Usage Source Durability and Refresh Defects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `systematic-debugging` and `diagnosing-bugs` for Task 0 and Task 1, `swift-security-expert` for any Keychain or credential change, and `writing-for-interfaces` for every user-facing state. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop Claude usage from depending on a cross-app Keychain grant that does not stay granted, and fix the three defects that make the Refresh button silently produce nothing while the CLI probe — run seconds later — works.

**Scope boundary:** This plan is *separate from* and *beneath* the [Claude delegated OAuth and setup plan](2026-07-31-claude-delegated-oauth-and-setup.md). That plan owns first-run enrollment, the auth state machine, and the app-owned credential capability gate. This plan owns **source durability** — making a reading obtainable when the borrowed Keychain credential is unavailable — and the **read-path defects** that exist today regardless of which credential wins that gate. Task 3 hands off to it rather than duplicating it.

**Architecture:** **Fit — no new architecture.** `ClaudeUsageCollector` stays the single tier owner, `ClaudeUsageMonitor` stays the single read-cycle owner. The changes are: a back-off that distinguishes reason, a refresh queue that cannot drop a user action, a passive tier that is actually installed and monitored, and a source-health projection the UI can state plainly.

**Tech Stack:** Swift 6.2, Foundation, Security/Keychain, URLSession, Claude Code CLI 2.1.227 contract, XCTest. No new dependency.

---

## Current Evidence

Captured 2026-08-12/13 on the development machine. All values are non-secret; no credential bytes were read.

| # | Observation | How obtained |
|---|---|---|
| E1 | Installed `/Applications/AgentUsageMonitor.app` is **Developer ID signed** (`<maintainer> (TEAMID)`), notarized and stapled, designated requirement pinned to `com.david.codex-usage-monitor` + team OU — **stable across rebuilds**. | `codesign -dv`, `codesign -d -r-` |
| E2 | Keychain item `Claude Code-credentials`: `cdat` **2026-07-20T02:32:03Z**, `mdat` **2026-08-13T00:53:42Z**. Creation date is unchanged since July; the modification date tracks recent Claude Code activity. Claude Code **updates the item in place** and does so often — it does not delete and recreate it. | `security find-generic-password -s "Claude Code-credentials"` (attributes only; no `-w`, so no secret read and no prompt) |
| E3 | `~/.claude/settings.json` `statusLine.command` is `cd '~/Desktop/<superseded-project-dir>/ClaudeUsageBridge' && python3 -m claude_usage_bridge --quiet`. **That directory does not exist.** Every status-line render fails. | `ls`, settings read |
| E4 | **No `claude-rate-limits.json`** exists in `~/Library/Application Support/CodexUsageMonitor/`. Tier 3 has never produced a snapshot on this machine. | directory listing |
| E5 | `ClaudeStatusLineInstaller` has **no call site in app code** — only tests reference it. The shipped app cannot install or repair the passive tier. | repository-wide grep |
| E6 | The only local Claude data present is `claude-usage-cache.json` (tier 4) and `last-known-good.json`. So when tier 1 fails there is exactly one fallback, and it is a cache. | directory listing |
| E7 | Claude Code **2.1.227** exposes `setup-token`, `auth login`, `auth logout`, `auth status`. | `claude --version`, `--help` |
| E8 | `~/.claude/.credentials.json` does not exist. On macOS the Keychain item is the only borrowed credential store. | `ls` |
| E9 | The app's in-bundle probe (`--claude-live-read-once`, same signed binary → same ACL entry) returned tier 1 live in about a second **with no dialog**: `5h 13.0% · 7d 2.0% · plan pro · via Claude Code credentials`. The grant was in effect. | probe run 2026-08-13T01:19:27Z |
| E10 | The same probe's tier 4 showed the **running app** had written a cache at 01:17:14Z — a `.never`-policy read, which can only succeed while the ACL grants access without interaction. Background reads were working too. | probe output |
| E11 | Only one bundle exists on disk and it is the running process. A second, differently-signed build alternating with the release build is ruled out. | `mdfind`, `ps` |

**What E1 rules out.** The repository's only documented cause for a returning "Always Allow" prompt is ad-hoc signing, where the designated requirement is the binary's cdhash and changes every build ([PR 1 note](../../pr/1-claude-usage-provider.md), [README](../../../README.md), [release guide](../../development/releasing-on-github.md)). The reported reprompting is happening on a **stably signed, notarized** build, so that explanation does not apply and the real cause is **unidentified**. Task 0 identifies it before anything is built on top of it.

---

## Defects

| ID | Defect | Location | Reported symptom it explains |
|---|---|---|---|
| **D1** | The 429 back-off gate wraps the whole tier-1 attempt and is not conditioned on the refresh reason, so a **user-initiated** Refresh is skipped for up to 15 minutes. Tier 1 is never entered, so the Keychain is never read, so no permission dialog can appear. | [ClaudeUsageCollector.swift:67](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift#L67) | "the refresh button doesn't work and I don't get usage data, and the Keychain dialogue isn't triggered" |
| **D2** | `refreshNow` returns immediately when `isRefreshing` is set. A scheduled refresh holds that flag across an `await` (up to a 10 s request timeout), and the button press lands inside that window silently — no read, no state change, no message. The user's explicit action is discarded in favour of a non-prompting background read. | [ClaudeUsageMonitor.swift:112](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift#L112) | same as D1, plus "sometimes" — it depends on timing |
| **D3** | `oauthBackoffUntil` is in-memory and per-process. The `UsageProbe` CLI runs in a **separate process** with a fresh collector, so it has no back-off state and goes straight to a `.userInitiatedOnly` Keychain read. | [ClaudeUsageCollector.swift:44](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift#L44), [ClaudeUsageProbeCommand.swift:64](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageProbeCommand.swift#L64) | "it triggers after I use the CLI force a read refresh" — the CLI is not subject to the app's back-off, so it prompts where the app would not |
| **D4** | The passive status-line tier is dead in production (E3, E4, E5), so below tier 1 there is only a cache. A denied or backed-off tier 1 therefore means stale-or-nothing. | installer has no call site | "I don't get usage data" |
| **D5** | `ClaudeOAuthUsageSource.fetch` never inspects `credential.expiresAt` and the app never refreshes the borrowed token. An expired borrowed access token produces a 401 that is reported as generic `unauthorized`, indistinguishable from a revoked grant. | [ClaudeOAuthUsageSource.swift:128](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift#L128) | intermittent loss of live readings on a timescale of hours |
| **D6** | The Keychain grant's non-persistence on a stably signed build is unexplained. | — | "always allow doesn't seem to work consistently … reprompts after a few hours" |

**D1 + D2 + D3 together are the reported bug.** The button is gated or dropped, so it never reaches the Keychain; the CLI is neither gated nor dropped, so it does. Nothing about the Keychain grant needs to be wrong for that symptom to appear — which is why Task 1 ships before Task 0's conclusion is available.

---

## Global Constraints

- Non-prompting background reads are preserved exactly. `.appLaunch`, `.scheduled`, and `.menuOpened` keep `kSecUseAuthenticationUIFail`. Nothing in this plan may let a timer raise a system dialog.
- Endpoint rate safety is preserved. Relaxing the back-off for user-initiated reads must not permit unbounded manual hammering — see the [rate-safety contract](../../development/claude-usage-endpoint-rate-safety.md). A user-initiated read that bypasses back-off is itself rate-limited by a minimum interval and a bounded allowance.
- Existing custom `~/.claude/settings.json` content is never overwritten. A status-line command the app did not write is only ever *reported*, never replaced, without an explicit user action naming what will change.
- No credential value, token fragment, or account identity enters logs, diagnostics, test fixtures, or this repository. Task 0's evidence is timestamps and statuses only.
- Task 0 never revokes, rewrites, or deletes the user's working Claude Code credential, and never runs `claude auth logout`.
- Tier 2 (`claude -p /usage`) stays manual and consented — it costs tokens.
- Automated coverage is added only for reproduced defects. The existing suite stays green.

---

## File Structure

### Create

- `docs/development/claude-keychain-grant-durability.md` — Task 0's evidence record and conclusion.
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeSourceHealth.swift` — the per-tier availability projection consumed by the UI.
- `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeRefreshDefectTests.swift` — the D1/D2 reproductions.

### Modify

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`
- `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeStatusLineInstallerTests.swift`
- `docs/development/authentication-and-usage-collection.md`, `docs/product/follow-ups.md`, `docs/product/planning-board.md`

---

## Task 0 — Identify why the Keychain grant does not persist

The point of this task is to replace a guess with a fact. Do not implement a workaround for a cause that has not been demonstrated. **Partially run on 2026-08-13; evidence in [claude-keychain-grant-durability.md](../../development/claude-keychain-grant-durability.md).**

- [x] **Step 1: Record the baseline without secrets.** Done. Developer ID signed, stable identifier/team requirement, build 266, Claude Code 2.1.227, `cdat` 2026-07-20T02:32:03Z / `mdat` 2026-08-13T00:53:42Z.
- [x] **Step 6: Check for a same-app second identity.** Done, and **ruled out** — `mdfind` finds exactly one bundle and `ps` shows it is the running one. (Run early because it is the cheapest way to invalidate the whole question.)
- [x] **Step 2 (non-interactive form): Establish that the grant currently works.** Done via the app's own in-bundle probe, which runs inside the same signed binary and therefore against the same ACL entry. Tier 1 returned live usage in about a second **with no dialog**, and tier 4 showed the running app's own *non-prompting* scheduled read had written a cache two minutes earlier. The grant was live for both policies. **The failure is a transition, not a steady state.**
- [ ] **Step 3+4: Catch the transition.** A three-minute sampler records `mdat`, the app's cache `savedAt`, and whether the app is alive. The scheduled read is non-prompting, so `savedAt` advancing *is* an assertion that the grant still works, and the moment it stalls while the app is running is the moment the grant died. Discriminator: a stall immediately following an `mdat` advance implicates the credential rewrite; a stall with `mdat` unchanged implicates time or the login session.
- [ ] **Step 5: Test the remaining candidates interactively.** (a) Lock/unlock the login keychain, then re-read. (b) Leave the app idle past the reported "few hours" with no Claude Code activity, then re-read. **Needs the user at the keyboard** — a dialog has to be observed and answered.
- [ ] **Step 7: Complete the evidence record.** Fill in the reproducing trigger, elapsed times, and `mdat` transitions. If nothing reproduces, say so — an unreproduced cause is a finding, not a gap to fill with a guess.

**Already settled by the partial run:** the ad-hoc-signature cause is ruled out (stable requirement), a second app identity is ruled out (one bundle), and item recreation is ruled out as the mechanism (`cdat` static since July while `mdat` moves). The ACL cannot be read directly — no API exposes a Keychain item's ACL without an authorization prompt — so it is measured by behaviour throughout.

---

## Task 1 — Make an explicit Refresh always perform a real read

Ships independently of Task 0's conclusion. This is the reported bug. **Implemented 2026-08-12 on `fix/claude-refresh-defects`; 6 regressions, 5 of which fail against the previous build.**

- [x] **Step 1: Reproduce D1.** In `ClaudeRefreshDefectTests`, drive the collector with a stubbed source that returns `rateLimited(retryAfter: now + 15m)`, then call `refresh(reason: .userInitiated)` and assert the stub **was** asked again. Fails today.
- [x] **Step 2: Reproduce D2.** Start a `.scheduled` refresh against a source suspended on a continuation, call `refreshNow(reason: .userInitiated)` while it is in flight, then release it. Assert a user-initiated read reached the source. Fails today.
- [x] **Step 3: Condition the back-off on reason.** `.userInitiated` bypasses `oauthBackoffUntil`. Guard the bypass with its own minimum interval (proposal: at most one bypassing read per 60 seconds, and at most 5 within the back-off window) so a held-down button cannot compound a 429. A bypass that is itself refused must return a **stated** result — "Rate limited by Anthropic until HH:MM · showing last reading" — never a silent fall-through.
- [x] **Step 4: Replace the drop with supersede.** `refreshNow` must not discard a user action. When a refresh is in flight and a `.userInitiated` request arrives, cancel or await the in-flight read and then run the user-initiated one; a second `.scheduled` request while busy still coalesces. Preserve the existing rule that a late result cannot overwrite a newer state.
- [x] **Step 5: Make the no-op visible.** Any Refresh that ends without a live reading publishes one specific reason — backed off, Keychain denied, credential absent, credential rejected, offline, no source — with one verb-labelled action. A pressed button that changes nothing on screen is itself the defect.
- [x] **Step 6: Reconcile D3.** The CLI probe reports which tier served and whether the app's back-off would have applied, so the app and the CLI can no longer disagree without saying why. The CLI's independent back-off state stays acceptable and is documented, not hidden.
- [x] **Step 7: Verify.** Run the new regressions and the full existing Claude suite.

---

## Task 2 — Revive the passive status-line tier as a first-class keychain-free source

**Steps 1–4 implemented 2026-08-16** on `fix/claude-passive-capture-revival`; 10 regressions. Verified read-only against the real machine: its configured command classifies as `repairable — supersededProjectBridge`. **Step 5 remains open** — it needs the user to confirm the repair and run one Claude Code turn.

This is the durable answer to "a more consistent way to get usage": a source that needs **no Keychain grant, no network call of ours, and no token**, and that refreshes on every Claude Code turn.

- [x] **Step 1: Give the installer a call site.** Wire `ClaudeStatusLineInstaller` into the Claude Agent settings page as an explicit user action. It is currently reachable only from tests (E5), which is why no snapshot has ever been written.
- [x] **Step 2: Distinguish a stale predecessor from a real custom status line.** `install()` today returns `.existingCustomStatusLineFound` for *any* foreign command, including this project's own dead Python bridge pointing at a deleted directory (E3). Add detection for: a command naming a path that does not exist, and a command matching an earlier bridge this project itself installed. Report those as **repairable**, with the exact old and new command shown, and replace only on an explicit confirmation. A genuine third-party status line stays untouched, as today.
- [x] **Step 3: Surface capture health.** Show when the last snapshot was written, or state that none has ever been. `capturedAt` already flows through [ClaudeRateLimitSnapshotReader](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift); the missing part is telling the user that the tier is dead rather than merely quiet.
- [x] **Step 4: Add the reproduced installer regressions.** A settings file whose status-line command points at a missing path is classified repairable; a live third-party command is not; a confirmed repair rewrites only `statusLine` and preserves every other key byte-for-byte; a malformed settings file is still refused.
- [ ] **Step 5: Verify against a real Claude Code turn.** Install, run one turn, confirm `claude-rate-limits.json` appears with plausible windows, then confirm the app serves tier 3 with tier 1 unavailable. Record it in the verification section — this is the acceptance that E4 currently fails.

---

## Task 3 — Move tier 1 onto an app-owned token via `claude setup-token`

This is the structural fix for D6. An app-owned Keychain item carries **our own** ACL, so no cross-app grant exists to lose — the question in Task 0 stops being load-bearing for ordinary refresh, whatever its answer turns out to be.

### Why `setup-token` and not a self-run PKCE flow

The [2026-07-21 spike](2026-07-21-claude-oauth-web-login-spike-findings.md) proved a self-run PKCE authorize request is *accepted*, but only by presenting **Claude Code's own public `client_id`**. That is disqualifying here for three independent reasons, and the token exchange was never actually observed (the endpoint IP-throttled at 429), so the path is unproven as well as unsuitable:

1. The delegated-OAuth plan's constraints forbid it outright — "the app never reuses Claude Code's OAuth client ID in its own authorization request."
2. The consent screen would say "Claude Code" while a different application receives the token. That is a misrepresentation to the user at the moment of granting access, and this repository is now public.
3. It would require this app to run its own `/v1/oauth/token` exchange, which the shipped design has never done.

`claude setup-token` avoids all three: **Claude Code runs its own flow under its own identity**, the consent screen is truthful because Claude Code genuinely is the client, and it hands back a long-lived token intended to be given to another tool. We run no exchange and impersonate nothing.

- [ ] **Step 1: Re-run the capability gate.** Execute [Task 0 of the delegated OAuth plan](2026-07-31-claude-delegated-oauth-and-setup.md#task-0--re-run-the-delegated-oauth-capability-gate) against Claude Code **2.1.227** (installed; the plan's evidence is 2.1.220, and `setup-token` is still present, so the re-test is not blocked). Attach [claude-keychain-grant-durability.md](../../development/claude-keychain-grant-durability.md) as the evidence for *why* the borrowed credential cannot remain the only tier-1 method.
- [ ] **Step 2: Capture the token without ever letting it touch disk or a log.** `setup-token` is interactive and prints the token on completion, so the runner needs a PTY, an in-memory-only buffer, a parser that retains **only** the token bytes and discards all surrounding output, and typed errors that carry no captured text. No shell history, temp file, `tee`, debug log, diagnostics field, or test fixture may ever receive it. The prior 401 is treated as **unreproduced**, not as a verdict — re-test before concluding anything.
- [ ] **Step 3: Correct the app-owned store before storing anything in it.** `ClaudeSelfIssuedCredentialStore` currently uses delete-then-add, omits `kSecUseDataProtectionKeychain`, has no stable `kSecAttrAccount`, and performs synchronous Keychain calls without actor isolation. Those are release-blocking the moment this item becomes the primary credential. Move CRUD into the `ClaudeCredentialActor` the delegated plan already specifies: add-or-update (never delete first), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` because scheduled reads must work while locked, every `OSStatus` handled, `errSecInteractionNotAllowed` treated as retry-later and **never** as a reason to delete.
- [ ] **Step 4: Drop implicit environment adoption.** `CLAUDE_CODE_OAUTH_TOKEN` is honoured today at *read* time, so a stray variable can silently become the production credential and mask which method is actually serving. Restrict it to the command-line probe or remove it; it must not create enrollment or be selected without the user choosing it.
- [ ] **Step 5: Make the method explicit and non-silent.** The user picks the method; a failure of the chosen one degrades **visibly** through `ClaudeEffectiveMethodRecorder` and never silently swaps to the other. A long-lived token also has no refresh, so revocation surfaces as a 401 that must be reported as "reconnect", not retried forever.
- [ ] **Step 6: Record the outcome either way.** If the gate accepts, tier 1 moves to the app-owned item and the borrowed Keychain read becomes an explicitly-chosen compatibility fallback. If it rejects, **Task 2's passive tier is the durability answer for this release**, and that limitation must be stated plainly in the README, the app's Data & Privacy page, and the release notes rather than left implied.

---

## Task 4 — Handle the expiring borrowed token honestly (D5)

- [ ] **Step 1: Read `expiresAt` before the request.** A borrowed credential already past expiry is a known-stale credential; classify it as such instead of spending a network call to discover a 401.
- [ ] **Step 2: Separate the two 401 meanings.** "Expired — Claude Code will refresh it on its next run" and "rejected — reconnect" are different states with different actions. Never call `/v1/oauth/token` ourselves; the refresh belongs to Claude Code.
- [ ] **Step 3: Prefer a fresher local reading over a stale live one.** The collector already ranks tier 3 and tier 4 by `capturedAt`; a known-expired tier-1 credential must not outrank a fresh passive capture.

---

## Task 5 — Verification and documentation

- [ ] Run `xcodebuild` for the main macOS scheme; expected exit 0 and no new warnings.
- [ ] Run the new D1/D2 and installer regressions; expected exit 0.
- [ ] Run the full existing test suite; expected exit 0.
- [ ] Build the signed `.app` and verify signature and resources.
- [ ] Exercise in the signed app: Refresh during an in-flight scheduled read; Refresh during a 429 back-off; Refresh with the Keychain denied; Refresh with the Keychain allowed; status-line repair from the stale Python command; a Claude Code turn producing a snapshot; tier 3 serving with tier 1 down; expired borrowed token; disconnect and reconnect.
- [ ] Confirm no scheduled refresh raises a dialog across at least one full poll interval in each state above.
- [ ] Inspect unified logs and diagnostics for token fragments. Expected: none.
- [ ] Update `docs/development/authentication-and-usage-collection.md` (the four-tier section now states the reason-conditioned back-off and the supersede rule), follow-ups, and the planning board.
- [ ] Run `git diff --check`; expected exit 0.

---

## Review Checklist

- No timer-driven path can reach a prompting Keychain read.
- No user-initiated action can be silently discarded.
- Every refresh that produces no live reading states why, in one sentence, with one action.
- Relaxing back-off for user actions is bounded and cannot compound a 429.
- The status-line repair never overwrites a status line this project did not write, without explicit confirmation naming the exact change.
- Task 0's conclusion is evidence, not inference; an unreproduced cause stays recorded as unreproduced.
