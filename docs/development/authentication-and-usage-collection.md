# Authentication & usage collection: Codex and Claude

This document explains, per provider, **how the app authenticates** and **how it reads usage**. The two providers are deliberately different because Codex and Claude expose their account and quota data through entirely different mechanisms.

The guiding principle for both is the same: **this app never implements a provider
token exchange and never stores a provider password.** Claude delegates its primary
flow to `claude setup-token`, then stores the result in an app-owned Keychain item.
Every automatic refresh is designed so it can never interrupt the user with a
system prompt.

---

## Part 1 — Codex

### 1.1 How we authenticate with Codex

Codex has **no credential of ours to store**. The Codex CLI owns its own login session and keychain entry; we only ever *ask it* about its state.

All interaction happens through a short-lived **app-server subprocess** speaking newline-delimited JSON-RPC over stdio:

```
codex app-server --listen stdio://
```

See [CodexAppServerProcess](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexAppServerSession.swift#L75). Every session follows the same handshake ([CodexProtocol](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexProtocolModels.swift#L20)):

| id | method | purpose |
|----|--------|---------|
| 1  | `initialize` + `initialized` notification | open the session |
| 2  | `account/read` (`refreshToken: false`) | who is signed in / connection status |
| 3  | `account/rateLimits/read` | quota windows |
| 4  | `account/usage/read` | usage / credits |
| 5  | `account/login/start` (`type: chatgpt`) | begin browser sign-in |

**Locating the CLI** — [CodexExecutableLocator](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexAppServerSession.swift#L23) searches, in order: `CODEX_EXECUTABLE`, the Homebrew/`/usr/local`/`/usr/bin` prefixes, every directory on `PATH`, and the bundled `openai.chatgpt-*` VS Code extension. A GUI `.app` does not inherit the login shell's `PATH`, so the explicit prefixes matter.

**Reading connection status** ([CodexConnectionService.readStatus](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionService.swift#L29)):
- executable missing → `missingCLI`
- `account/read` returns an account → `connected` (with `planType`)
- otherwise → `disconnected`

**Two sign-in methods**, both driven by [CodexConnectionController](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift):
1. **Browser** ([startBrowserLogin](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionService.swift#L53)) — send `account/login/start`, open the returned `authUrl` (must be `https`) in the default browser, then wait for the `account/login/completed` notification carrying `success: true`. After completion we re-read `account/read` to confirm the connected identity.
2. **CLI** ([signInWithCLI](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/CodexConnectionController.swift#L202)) — open Terminal (via AppleScript) running `codex login`, then poll `codex login status` until it exits `0` and `account/read` returns an account.

**App-local disconnect** is a *persisted flag on our side only* — it hides Codex and stops auto-detection without touching the Codex CLI session or its stored credential. While set, the still-valid CLI login is deliberately not auto-reconnected.

### 1.2 How we read Codex usage

[CodexQuotaCollector.refresh](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexQuotaCollector.swift#L12) opens a fresh app-server session and issues `account/read` + `account/rateLimits/read` + `account/usage/read` ([collectSample](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexAppServerSession.swift#L58)).

Parsing ([parseSample](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexProtocolModels.swift#L63)):
- The account **email is never stored** — it is SHA-256 fingerprinted (first 8 bytes) purely to detect an account switch.
- The `codex` rate-limit lane exposes a `primary` and `secondary` window. We classify by `windowDurationMins`: `10080` (7 days) is the **weekly** window; the other is the **5-hour** window.
- Credits, `hasCredits`, and reset-credit expiry timestamps are carried through for the credits card.

**Confirmation by agreement** — a single app-server read can return a transient empty snapshot, so `refresh()` takes **three samples one second apart** and only marks the result `confirmed` when **≥2 non-empty samples agree** ([resolve](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexQuotaCollector.swift#L28)). If the fresh samples don't agree, it falls back to the last-known-good value from [QuotaStateStore](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/CodexQuotaCollector.swift) and labels it `cachedLastKnownGood`.

**Summary:** Codex = local subprocess only. No network calls of ours, no credential of ours, an authoritative reading every refresh, cross-checked across three samples.

---

## Part 2 — Claude

Claude is the opposite shape: authentication produces (or borrows) a **bearer token**, and usage comes from a **network endpoint**, with three local fallbacks behind it.

### 2.1 How we authenticate with Claude

The feature branch exposes two explicit methods. **Connect with Claude** is primary:
Claude Code performs `claude setup-token` in a cancellable PTY, the app validates
the candidate against usage, then stores it in its own data-protection Keychain
item. **Use Claude Code credentials…** is compatibility-only. The app persists only
the selected method in `UserDefaults` key `claude.credential-method.v1`; it never
switches methods automatically. GUI environment-token and paste-token adoption are
not supported.

**Method (a): app-owned setup token** *(primary)*

The stable generic-password item uses service `AgentUsageMonitor-ClaudeOAuth`,
account `setup-token-v1`, `kSecUseDataProtectionKeychain: true`, and
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Writes update first and add only
on not-found; they never delete first. A pre-release service-only item is migrated
only after the scoped replacement round-trips. Disconnect deletes only this item.

**Method (b): borrow Claude Code's own credential** *(explicit compatibility)*
[ClaudeKeychainCredentialStore](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L49) reads Claude Code's existing login-Keychain item, service **`Claude Code-credentials`**, and decodes its `claudeAiOauth` JSON (access token, optional refresh token, `expiresAt` in ms, scopes, `subscriptionType`). We never run a sign-in flow and never copy the token elsewhere.

Reading another app's Keychain item is an **ACL-gated cross-app access** that *can* raise the macOS permission dialog. That is governed by [KeychainPromptPolicy](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L27):
- `.never` — supplies an `LAContext` with interaction disabled, so the read **fails instead of prompting**. Used by *every automatic refresh*. `errSecInteractionNotAllowed` remains a temporary, non-destructive condition.
- `.userInitiatedOnly` — allows the prompt. Only ever reached from an explicit button press.

The mapping from refresh reason to policy lives in [ClaudeRefreshReason](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift#L3): only `.userInitiated` may prompt; `appLaunch` / `scheduled` / `menuOpened` never can.

**No implicit cross-method fallback.** [ClaudeCompositeCredentialStore](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeCompositeCredentialStore.swift) reads only the selected method. A rejected setup token is deleted and requires reconnect; it never invokes Claude Code refresh or borrowed access. A rejected borrowed credential may ask Claude Code to refresh, but the subsequent read is non-interactive.

> The credential itself ([ClaudeOAuthCredential](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Connection/ClaudeOAuthCredential.swift#L7)) is intentionally **not** `Codable`, `CustomStringConvertible`, or `CustomDebugStringConvertible` — nothing about the token should be persistable or printable by accident. It lives in Keychain only.

### 2.2 How we read Claude usage — a four-tier fallback

[ClaudeUsageCollector.refresh](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCollector.swift#L66) first serves a valid status-line snapshot captured within the last two minutes, before invoking any credential provider. If that zero-secret fast path is absent or older, the automatic runtime order is OAuth → best local status-line/cache reading. Tier 2 remains manual-only.

**Tier 1 — OAuth usage endpoint** *(authoritative, networked)*
[ClaudeOAuthUsageSource.fetch](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift#L128) issues:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/2.0.0
```

- Requires the credential to carry the **`user:profile`** scope (pre-checked before any network call).
- The **`User-Agent` is mandatory**: without a `claude-code/<version>` agent the endpoint drops the caller into an aggressive rate-limit bucket that returns persistent 429s.
- Response parsing pulls the `five_hour` and `seven_day` utilization windows, any `limits[]` scoped windows, and `extra_usage` credits. ISO-8601 timestamps (incl. microsecond fractional seconds) are parsed by [ClaudeOAuthDateParsing](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeOAuthUsageSource.swift#L30).
- **Status handling:** 401/403 → `unauthorized`; 429 → `rateLimited(retryAfter:)`; other non-200 → `serverFailure`.
- **429 back-off:** on a 429 the collector stops calling the endpoint until `Retry-After` (or a default 15 min) elapses and serves local sources instead — hammering `/api/oauth/usage` during a limit only compounds it. See [docs/development/claude-usage-endpoint-rate-safety.md](./claude-usage-endpoint-rate-safety.md).

**Tier 2 — Claude Code CLI `/usage` probe** *(manual, consented — costs tokens)*
[ClaudeCLIUsageProbe](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeCLIUsageProbe.swift#L20) runs `claude -p /usage` and parses the 5-hour / weekly percentages out of the panel text (after stripping ANSI). It is **never automatic**: it may consume a small amount of Claude quota, so it sits behind an explicit first-use confirmation and exists only to force a fresh reading.

**Tier 3 — statusLine snapshot** *(passive, local, free)*
Claude Code renders a status line on every turn. We install a native helper, **`claude-usage-bridge`** ([main.swift](../../CodexUsageMonitor/Sources/ClaudeUsageBridge/main.swift)), into `~/.claude/settings.json`'s `statusLine` command via [ClaudeStatusLineInstaller](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift) (which merges non-destructively and never clobbers an existing custom status line). Claude Code pipes its status-line JSON to the helper on each render; the helper extracts only the `rate_limits` windows and writes `Application Support/CodexUsageMonitor/claude-rate-limits.json`. [ClaudeRateLimitSnapshotReader](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeRateLimitSnapshotReader.swift) reads that file (best-effort, never throws). This costs nothing but is only as fresh as the last time Claude Code ran.

In 0.0.1 that helper is a second Mach-O executable nested in the app bundle. The
build signs it first and then signs the containing app, so it is operationally
correct but expands the signing, verification, and notarization surface. Product
Follow-up 10 tracks consolidating the same stdin-driven helper mode into the main
app executable. The replacement must still exit without creating UI, preserve the
field-scoped privacy boundary and atomic snapshot write, remain safe when invoked
by Claude Code, and keep installation/update paths stable.

**Tier 4 — cache** *(last resort)*
[ClaudeUsageCache](../../CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageCache.swift) holds the most recent successful snapshot from any source. If nothing else is available, the last good reading is shown labelled `cached`; if even that is empty, a "no source available" warning is returned.

**Freshness ordering nuance** — a status-line capture under two minutes old is the credential-free fast path. After an OAuth failure, a status-line capture can still be *days* old if Claude Code has not run, while a cached OAuth read could be newer. The collector compares `capturedAt` and serves whichever local reading is actually fresher.

---

## Part 3 — Side-by-side

| | **Codex** | **Claude** |
|---|---|---|
| Credential ownership | Codex CLI owns it; we store nothing | App-owned setup token, or explicitly borrowed Claude Code credential |
| Our token storage | none | device-bound Keychain item for setup-token only |
| Auth transport | `codex app-server` JSON-RPC over stdio | official CLI setup flow, then selected Keychain item |
| Sign-in methods | browser (`account/login/start`) · CLI (`codex login`) | setup-token primary · Claude Code credentials compatibility |
| Usage source | app-server `rateLimits/read` + `usage/read` | OAuth `GET /api/oauth/usage` (+ 3 local fallbacks) |
| Networked read of ours? | **No** — all local subprocess | **Yes** — tier 1 only; tiers 2–4 are local |
| Reliability strategy | 3 samples, confirm on agreement, else last-known-good | fresh statusLine fast path → OAuth → best local reading; explicit CLI probe |
| Can a background refresh prompt? | No | No — `.never` policy forbids the Keychain dialog off explicit actions |

## Part 4 — Cross-cutting safeguards

- **No background prompts.** Codex reads are local subprocess calls; Claude borrowed reads disable Keychain interaction. Only an explicit compatibility action can surface its system dialog.
- **No token exchange of ours.** Codex and Claude setup-token login are performed by their official CLIs; this app never calls `/v1/oauth/token`.
- **Degrade, don't dead-end.** Both providers prefer a labelled, older-but-real reading over a blank one — Codex via last-known-good, Claude via its passive/cache ladder and explicit recovery actions. Credential methods never switch silently.
- **Minimal identity retention.** Codex account emails are fingerprinted, not stored; Claude tokens live only in Keychain and are kept out of logs by design.

### Related documents
- [docs/development/claude-usage-endpoint-rate-safety.md](./claude-usage-endpoint-rate-safety.md) — the 429 back-off contract for tier 1
- [docs/claude-usage-verification.md](../claude-usage-verification.md) — verifying Claude readings against the CLI
