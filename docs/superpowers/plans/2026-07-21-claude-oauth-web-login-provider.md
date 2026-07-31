# Claude Credential Methods + Source Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The Task 0 feasibility spike is **done** (see banner); implementation may proceed.

**Goal:** Give Claude the same **two-method sign-in model Codex already has**, and formalize the full source hierarchy beneath it. Tier 1 (OAuth) gains **two co-equal, user-selectable credential methods** — **browser sign-in** (`claude setup-token`) and **Claude Code credentials** (the existing Keychain read) — presented side by side exactly like Codex's "Sign in with browser" / "Sign in with Codex CLI…". Neither is a silent fallback of the other: the user picks, so the Keychain ACL grant becomes an **explicit, informed choice** rather than something that happens to them.

> **⚠️ STATUS UPDATE (2026-07-22) — method (a) SHELVED as unresolved; method (b) is the working default.**
> `claude setup-token` was implemented (`ClaudeSetupTokenService`, unit-tested) but **never verified end-to-end against a real token**. A live attempt returned `401 Invalid bearer token` from `/api/oauth/usage` — but the free `/v1/models` control **also** 401'd under both auth schemes, so the token was not accepted anywhere and the result proves nothing either way (likely a token truncated by the Safari HTTPS-Only callback detour). See the [spike findings addendum](2026-07-21-claude-oauth-web-login-spike-findings.md#addendum--claude-setup-token-shelved-as-unresolved-2026-07-22) for the decisive re-test.
> **Consequence:** tier 1 runs on **method (b), Claude Code credentials (Keychain)** — the only path proven live (`5h 26.0% · 7d 20.0% · plan pro`). `ClaudeSetupTokenService` stays in the tree but is **not wired to any UI** and must not be presented as working. Work is proceeding on hardening method (b) instead.

## Source hierarchy (authoritative order, as of 2026-07-21)

| Tier | Source | Status |
|---|---|---|
| **1** | **OAuth** — via **(b) Claude Code credentials (Keychain)** [working default] or **(a) browser sign-in (`setup-token`)** [SHELVED, unverified] | (b) live; (a) built but unproven |
| **2** | CLI `/usage` PTY probe | deferred (own plan) |
| **3** | statusLine passive snapshot | built |
| **4** | cached last-known-good | built |

Tier 1's two methods are peers *within* tier 1 — whichever the user connected with is tried first, with the other as an automatic degrade before dropping to tier 2. Tiers 2–4 are unchanged by this plan; `ClaudeUsageCollector` and the `--claude-live-read-once` probe already reflect this numbering.

## Where this sits (state as of 2026-07-21)

- **Tier 1 works today via method (b) only.** Against a real Pro account the collector's OAuth path returns `5h 10.0% · 7d 14.0% · plan pro` — verified via the `--claude-live-read-once` probe ([ClaudeUsageProbeCommand.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageProbeCommand.swift)).
- **Method (b) is `ClaudeKeychainCredentialStore`** ([ClaudeOAuthCredential.swift:28](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L28)). It reads Claude Code's Keychain item from our process → macOS raises an ACL dialog; only "Always Allow" makes it durable, and on an unsigned debug binary the grant doesn't survive rebuilds (ACL is keyed to code signature). **This is why it must be a chosen method with an explanation, not a default side effect.**
- **Method (a) does not exist yet.** This plan builds it.
- **Codex's precedent to mirror:** `AgentSignInMethod{.browser,.cli}`, `AgentConnectionState{.checking,.disconnected,.signingIn(method),.connected,.failed,.missingCLI}`, `CodexConnectionController.signInWithBrowser()/signInWithCLI()`, and the historical two-button `CodexDisconnectedMenuView.swift:17-20` implementation (later removed during the popover port).

## Why `claude setup-token` is method (a)'s mechanism

Anthropic's Claude Code CLI ships `setup-token`, which runs the browser OAuth flow itself and emits a **~1-year token** (`sk-ant-oat01-…`). Delegating to it — precisely how Codex delegates to `codex login` — beats a self-run PKCE flow on every axis:

| Axis | self-run PKCE | **`claude setup-token`** |
|---|---|---|
| Sanctioned | No — reuses Claude Code's `client_id` | **Yes** — official CLI command |
| Consent screen | Misleading ("Claude Code") | Anthropic's own |
| Token lifetime | short; needs refresh | **~1 year** |
| Keychain ACL prompt | none (own item) | **none** (own item) |
| Token-endpoint 429 | we perform the exchange (tripped it) | **CLI performs it** — we never call `/v1/oauth/token` |

Comparable tools corroborate the split: **CodexBar** reads Claude Code's Keychain item (our method b, prompt and all); **token-monitor** avoids credentials entirely by parsing `~/.claude/projects/` logs with `tokscale`, but only produces *estimates*, never the account's real percentages. Authoritative numbers require tier 1.

> **Task 0 spike RESULT (2026-07-21) — see [spike findings](2026-07-21-claude-oauth-web-login-spike-findings.md).** A self-run PKCE authorize was **accepted** with Claude Code's public `client_id`, `redirect_uri` `console.anthropic.com/oauth/code/callback`, scope `org:create_api_key user:profile user:inference`, `S256` — a real code was returned twice. The token-exchange `200` was never observed: this machine's IP is rate-limited (HTTP 429) on `/v1/oauth/token`, tripped by rapid retries. That is a network block, not a parameter rejection — and `setup-token` makes it irrelevant, since the CLI performs the exchange. Self-run PKCE is therefore retained **only** as a documented last resort (Task 6).

## Architecture

Mirrors the Codex connection layer one-for-one so Claude reads as part of the same system:

- **`ClaudeSignInMethod`** (new, `Equatable, Sendable`): `.browser` (setup-token) / `.claudeCodeCredentials` (Keychain), each with a `displayName` — the direct analogue of `AgentSignInMethod`.
- **`ClaudeConnectionState`** (new): `.checking`, `.notConnected`, `.signingIn(ClaudeSignInMethod)`, `.connected(ClaudeAccountSummary)`, `.failed(ClaudeConnectionFailure)`, `.missingCLI` — mirroring `AgentConnectionState`, including per-failure `displayMessage` copy that names the *other* method as the recovery path (as Codex's copy already does).
- **`ClaudeConnectionController`** (new, `@MainActor ObservableObject`): `signInWithBrowser()` and `useClaudeCodeCredentials()`, both funnelling through a shared `beginSignIn(using:operation:)` exactly like `CodexConnectionController`. Publishes `ClaudeConnectionState`; persists the succeeding method.
- **`ClaudeCredentialProviding`** ([ClaudeOAuthCredential.swift:21](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L21)) stays the single seam `ClaudeOAuthUsageSource` depends on — unchanged.
- **`ClaudeSelfIssuedCredentialStore: ClaudeCredentialProviding`** (new) — our **own** Keychain generic-password item (`"AgentUsageMonitor-ClaudeOAuth"`). Because our app creates it, our reads never raise an ACL prompt. Backing store for method (a).
- **`ClaudeSetupTokenService`** (new, actor) — method (a)'s mechanism: resolve token by (1) `CLAUDE_CODE_OAUTH_TOKEN` env var, (2) spawn `claude setup-token` via a new `ClaudeExecutableLocator` (mirroring `CodexExecutableLocator`) and capture the `sk-ant-oat01-…` from stdout, (3) manual paste. Validate with one `GET /api/oauth/usage`, then persist to `ClaudeSelfIssuedCredentialStore`.
- **`ClaudeKeychainCredentialStore`** (existing) — method (b), unchanged except for the prompt policy from the [wiring plan](2026-07-21-claude-usage-provider-wiring.md) Task 1.
- **`ClaudeCompositeCredentialStore: ClaudeCredentialProviding`** (new) — resolves **the user's connected method first**, then the *other* method as an automatic degrade, then reports unavailable so the collector falls to tier 2/3/4. It never silently swaps methods without that being visible in the surfaced source label.
- **Expiry, not short-cycle refresh:** the ~1-year token means no 60-min refresh clock. A `401/403` from `/api/oauth/usage` deletes the self-issued item and surfaces "re-run Claude sign-in," then degrades to method (b).
- **Keychain hygiene:** self-issued item uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, app-only ACL, no synchronizable/iCloud flag. "Sign out" deletes it.

**Tech Stack:** Swift 6.2, Foundation, `Security` (Keychain), `Process` (spawn `claude`), Combine (`ObservableObject`), SwiftUI, XCTest. `CryptoKit`/`Network.framework` only if the PKCE last resort (Task 6) ships. No new dependencies.

## Global constraints

- **Do not weaken any privacy/security boundary** from `claude_probe_plan` §11: no token logged, no token in error reports, no token written outside Keychain, no token in the usage cache.
- **Sign-in is user-initiated only** — both methods must never run on a background/scheduled refresh.
- **The `sk-ant-oat01-…` token is captured from the CLI's stdout straight into Keychain** — never a temp file, log, diagnostic, or the probe. It is a ~1-year, password-equivalent credential; treat it with *more* care than a 60-min access token.
- **Method (b) must state what it grants** before triggering the ACL dialog: standing read access to Claude Code's live account token. No silent invocation.
- **TDD throughout.** Every task writes failing tests first (CLI, network, and Keychain fully injected — the suite never spawns a real process, opens a browser, or touches the real Keychain), and ends by running the full Claude suite against the 44-test baseline.

---

## Task 1: `ClaudeSignInMethod` + `ClaudeConnectionState` (the shared vocabulary)

- [x] **Step 1: Failing tests** (`ClaudeConnectionStateTests.swift`): `displayName` for both methods; `isConnected` only for `.connected`; each `ClaudeConnectionFailure.displayMessage` names the alternative method as recovery (mirroring `AgentConnectionFailure`'s copy convention).
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** both enums plus `ClaudeAccountSummary` (`planType`), modelled directly on [AgentConnectionState.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/AgentConnectionState.swift).
- [x] **Step 4: Run to verify they pass. Commit.**

## Task 2: `ClaudeSelfIssuedCredentialStore` — our own Keychain item

- [x] **Step 1: Failing tests** (`ClaudeSelfIssuedCredentialStoreTests.swift`, injected raw Keychain reader/writer — never the real Keychain): round-trips a `ClaudeOAuthCredential`; missing item → `.notFound`; corrupt data → `.malformedData`; `delete()` removes it; the write sets `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and no synchronizable flag.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** with `save(_:)`, `loadCredential()`, `delete()` against service `"AgentUsageMonitor-ClaudeOAuth"`, mirroring `ClaudeKeychainCredentialStore`'s injection seam.
- [x] **Step 4: Run to verify they pass. Commit.**

## Task 3: `ClaudeSetupTokenService` — method (a)'s mechanism

- [x] **Step 1: Failing tests** (`ClaudeSetupTokenServiceTests.swift`, injected env reader + process runner + `requestExecutor`):
  - env path: `CLAUDE_CODE_OAUTH_TOKEN` set → used directly, **no process spawned**.
  - CLI path: injected stdout containing `sk-ant-oat01-…` → token extracted (tolerant of surrounding log lines), nothing else from stdout retained.
  - manual-paste path: a pasted token is accepted and validated.
  - validation: one `GET /api/oauth/usage` (`anthropic-beta: oauth-2025-04-20`); `200` → persisted to a fake self-issued store; `401/403` → rejected, **nothing persisted**, typed error.
  - **secret hygiene:** the token never appears in any thrown error's description.
  - missing `claude` binary → `.missingCLI`.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** `ClaudeExecutableLocator` (mirror `CodexExecutableLocator`, incl. a `CLAUDE_EXECUTABLE` override) and the service. Capture stdout straight into the credential; never log it.
- [x] **Step 4: Run to verify they pass. Commit.**

## Task 4: `ClaudeCompositeCredentialStore` — selected method first, other as degrade

- [x] **Step 1: Failing tests** (`ClaudeCompositeCredentialStoreTests.swift`): connected-method `.browser` → self-issued store consulted first, Keychain store untouched (spy); connected-method `.claudeCodeCredentials` → the reverse; selected method failing → the other is tried and the **effective method is reported** (not silently masked); both failing → throws so the collector degrades to tier 2/3/4; a `401/403` on the self-issued token deletes it and signals re-sign-in.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** the composite (holding the persisted `ClaudeSignInMethod`) and switch `ClaudeUsageCollector`/`ClaudeOAuthUsageSource` construction to use it. Existing collector/monitor tests stay green.
- [x] **Step 4: Run the full Claude suite. Commit.**

## Task 5: `ClaudeConnectionController` + two-button UI (the user-facing pair)

- [x] **Step 1: Failing tests** (`ClaudeConnectionControllerTests.swift`, fake service): `signInWithBrowser()` → `.signingIn(.browser)` then `.connected`; `useClaudeCodeCredentials()` → `.signingIn(.claudeCodeCredentials)` then `.connected`; a failure maps to the right `ClaudeConnectionFailure`; a second sign-in is ignored while one is in flight (`connectionTask` guard, as Codex does); the succeeding method is persisted.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement** the controller mirroring `CodexConnectionController` (shared `beginSignIn(using:operation:)`, `applyState`, `mappedFailure`).
- [x] **Step 4: Build the UI** in the Claude Settings surface from [the wiring plan](2026-07-21-claude-usage-provider-wiring.md): **two peer buttons — "Sign in with browser" and "Use Claude Code credentials…"** — mirroring the historical `CodexDisconnectedMenuView.swift:17-20` implementation, plus a "Sign out" action. The Keychain button carries the one-line disclosure of what it grants. Connected state shows plan + which method is active.
- [x] **Step 5: Run the full suite. Commit.**

## Task 6 (LAST RESORT, optional): self-run PKCE `ClaudeOAuthLoginService`

Only for environments with no `claude` CLI. Carries the `client_id`-impersonation caveat; behind an "Advanced" disclosure, never a peer of the two main methods. **DROPPED (2026-07-21):** `setup-token` covers the browser method without impersonation, so this is deliberately not shipped. Kept here as a documented, rejected option.

- [ ] **Step 1: Failing tests** (injected `requestExecutor` + browser-opener + callback-source): `code_challenge` = base64url-unpadded SHA-256 of verifier, `S256`; authorize URL carries the spike's exact params; `state` mismatch rejected (CSRF); `200` → persisted, non-200 → typed error and nothing persisted.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** (`CryptoKit` PKCE, `NWListener` one-shot on `127.0.0.1`, `NSWorkspace.shared.open`), **single-attempt with backoff-on-429** per the spike findings. Never log code/verifier/token.
- [ ] **Step 4: Run to verify they pass. Commit.**

## Task 7: Probe + docs

- [x] **Step 1:** Teach `--claude-live-read-once` to report which tier-1 **method** resolved — `browser (setup-token)`, `claude-code-credentials`, or `pkce` — plus the tier that ultimately served the data. Never print the token.
- [x] **Step 2:** Update the [capability research gate](2026-07-20-claude-code-capability-research.md#gate-before-implementation) and planning board: tier 1 now has two user-selectable methods; record the tier 1–4 hierarchy table above.
- [x] **Step 3: Commit.**

---

## Explicitly deferred (not dropped)

- **Tier 2 — CLI `/usage` PTY probe.** Its own plan; slots between tier 1 and statusLine when built.
- **Self-run PKCE (Task 6).** Documented so the impersonation-caveated path is a conscious choice, not a silent default.
- **Multi-account handling / credential fingerprinting.** The self-issued item is single-account.

## Completion criteria

- The Claude Settings surface offers **two peer sign-in methods** — browser (`setup-token`) and Claude Code credentials — mirroring Codex's browser/CLI pair, with a "Sign out" action.
- Choosing browser sign-in yields live tier-1 usage with **no Keychain ACL prompt** and **no self-run token exchange** (no `/v1/oauth/token` 429 exposure).
- Choosing Claude Code credentials works as today, but only after an explicit disclosure of what it grants.
- If the selected method breaks, the other is tried and the **effective method is visible**; if both fail, the collector degrades tier 2 → 3 → 4 and never invents a number.
- The `sk-ant-oat01-…` token lives only in our own Keychain item, is deleted on sign-out, and never appears in logs, diagnostics, the probe, or the cache.
- Full Claude Swift suite green against the 44-test baseline.
