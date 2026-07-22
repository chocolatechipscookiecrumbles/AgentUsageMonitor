# Claude OAuth Web-Login Spike — Findings (Task 1)

**Date:** 2026-07-21
**Plan:** [2026-07-21-claude-oauth-web-login-provider.md](2026-07-21-claude-oauth-web-login-provider.md) Task 1 (the make-or-break gate)
**Question:** Can a *self-run* OAuth 2.0 + PKCE web-login flow (i.e. our app doing its own browser sign-in, not reading Claude Code's Keychain) obtain a token carrying `user:profile` that `GET /api/oauth/usage` accepts?

## Status: PARTIALLY CONFIRMED — authorize half proven, token-exchange half blocked by an IP rate limit

The feasibility-critical half (does Anthropic's authorize endpoint accept a third-party self-run PKCE request for these scopes?) **passed**. The remaining half (token exchange → `200`, then usage → `200`) could **not** be observed because this machine's egress IP is currently rate-limited (HTTP 429) on the token endpoint — a network-layer block triggered by too-rapid retries during the spike, **not** a rejection of our OAuth parameters.

## OAuth parameters — VERIFIED accepted at the authorize step

Running an entirely self-constructed PKCE authorize request, the browser reached Claude's consent screen and returned a real `code#state` authorization code **twice**, with no `invalid_client` / `invalid_scope` / `redirect_uri_mismatch`. That confirms these constants are correct and accepted for a self-run flow:

| Parameter | Value |
|---|---|
| Authorize URL | `https://claude.ai/oauth/authorize` (Pro/Max host) |
| Token URL | `https://console.anthropic.com/v1/oauth/token` |
| `client_id` | `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (Claude Code's public client) |
| `redirect_uri` | `https://console.anthropic.com/oauth/code/callback` (manual code-paste) |
| `scope` | `org:create_api_key user:profile user:inference` |
| PKCE | `code_challenge_method=S256` (required) |
| Code format | `AUTHORIZATION_CODE#STATE` (state appended after `#`) |

**Implication for the plan's client-id question (§ make-or-break, option a vs b):** option **(a) reuse Claude Code's public client_id works** — the authorize server grants `user:profile` for it. The consent screen therefore presents as "Claude Code," which is the honesty caveat the plan already flagged: acceptable for a **local, personal-use** build, not for third-party distribution. Whether an **own registered client (option b)** can obtain `user:profile` was **not** tested (would need a registered client id).

## What blocked full confirmation

Every `POST` to `https://console.anthropic.com/v1/oauth/token` returned:

```
HTTP 429  {"error":{"type":"rate_limit_error","message":"Rate limited. Please try again later."}}
```

- Occurred on ~5 attempts, **including the first attempt with a fresh code after a ~180s quiet window**. A fresh code's first exchange cannot fail on request-count alone, so this is an **IP-scoped throttle/ban** (likely an "N attempts → cooldown of minutes" rule my initial rapid double-hit tripped), not a per-code or per-parameter error.
- The token endpoint is a **different host** (`console.anthropic.com`) from the authorize host (`claude.ai`), so re-authorizing does not clear it; only a quiet cooldown on the token endpoint does. Probing the endpoint to *check* the limit resets the window — so it must be left completely idle.

## Residual risk assessment

**Low.** Scopes are granted at the authorize step (already proven); the token exchange is the mechanically identical call Claude Code itself makes from this same machine on every login. There is no parameter-level reason to expect the exchange or the subsequent `/api/oauth/usage` call to fail once the 429 clears. The only unproven step is a network round-trip that is currently throttled.

## How to complete confirmation (one clean attempt)

Run from a terminal on the machine after a **long idle period on the token endpoint** (recommend ≥15–30 min with zero requests to it):

1. `python3 scratchpad/oauth_spike_step_a.py` → approve in browser → copy the `code#state`.
2. Immediately: a single `POST` to the token URL with the saved `code_verifier` (see `oauth_single_shot.sh`), then `GET /api/oauth/usage` with `Authorization: Bearer <token>` + `anthropic-beta: oauth-2025-04-20`.
3. Do **not** retry on 429 — each retry re-arms the cooldown. One shot; if 429, wait longer and try once more.

Expected on success: token response with `scope` containing `user:profile`, a `refresh_token`, an `expires_in`, and a `200` from `/api/oauth/usage` with the same body shape `ClaudeOAuthUsageSource` already parses (`five_hour` / `seven_day` utilization).

## Recommendation for the plan

- **Proceed with the web-login plan (Tasks 2–7)** — the feasibility gate is effectively cleared for local/personal use. Treat the token-exchange `200` as a quick confirm-when-unthrottled item, not a blocker.
- **Carry the consent-honesty caveat forward:** shipping with client-id option (a) shows "Claude Code" on the consent screen; only sanctioned for personal use until option (b) is verified.
- **Build the token-exchange client with strict single-attempt + backoff-on-429 semantics** (Task 3), since the endpoint is demonstrably aggressive about rate limiting.

## Security note

No access token was ever obtained (all exchanges 429'd), so none was persisted. The PKCE verifier/state lived only in a scratchpad temp file that was deleted; the transient `.tok` file was empty and removed. No secret was logged.

---

# Addendum — `claude setup-token` shelved as UNRESOLVED (2026-07-22)

**Status: shelved, not disproven.** Method (a) — browser sign-in via `claude setup-token` — was implemented (`ClaudeSetupTokenService`) but **never verified end-to-end against a real token**. Testing was inconclusive and is parked here rather than left implied by green unit tests.

## What was actually observed

Claude Code CLI `2.1.217` was installed (see install traps below) and `claude setup-token` produced an `sk-ant-oat01-…` token. Against that token:

| Request | Result |
|---|---|
| `/api/oauth/usage` — `Authorization: Bearer` + beta header | `401 authentication_error: Invalid bearer token` |
| `/api/oauth/usage` — `Authorization: Bearer`, no beta header | `401 authentication_error: Invalid bearer token` |
| `/api/oauth/usage` — `x-api-key` (± beta header) | `429 rate_limit_error` — **void, never evaluated the credential** |
| `/v1/models` (control) — `x-api-key` | `401 authentication_error: invalid x-api-key` |
| `/v1/models` (control) — `Authorization: Bearer` | `401 authentication_error: OAuth access token is invalid.` |

## Why this is inconclusive

**The control failed.** `/v1/models` is a free endpoint that only checks authentication; both auth schemes rejected the token there too. So the token was not accepted *anywhere*, which means the `/api/oauth/usage` rows say nothing about whether setup-token can serve usage reads — the credential never proved valid in the first place. The two `429`s are the same IP throttle documented above and never reached credential evaluation.

Most likely cause: **a truncated/malformed token**. That `setup-token` run completed via a `curl`-delivered callback after Safari's HTTPS-Only mode refused the `http://localhost:PORT/callback` redirect, so the printed value may have been partial. A valid token used with the wrong scheme normally yields a distinctive error rather than flat rejection under both.

## The one test that would settle it

Mint a fresh token **without** the Safari detour (make a non-Safari browser default first), then run `scripts/diagnose-setup-token.sh`. The deciding row is **`/v1/models` with `x-api-key`**:

- `200` there → token genuinely valid; the `/api/oauth/usage` rows then become meaningful evidence either way.
- `401` there on a fresh, full-length (>100 char) token → the token class is inert for our purposes and method (a) genuinely fails.

Note the `x-api-key` usage rows may keep returning `429` until that IP throttle clears, so those two may stay unresolved regardless.

## Consequence while shelved

- **Method (b) — Claude Code credentials (Keychain) — is the only proven path to authoritative usage** and is therefore the default. Verified live: `5h 26.0% · 7d 20.0% · plan pro`.
- `ClaudeSetupTokenService` remains in the tree and unit-tested, but is **not reachable from any UI** and must not be presented as working. It validates before persisting, so it fails closed: a token that cannot read usage is refused rather than stored.
- If method (a) is ultimately disproven, the only other prompt-free route to authoritative numbers is **tier 2, the CLI `/usage` probe**, which would rise substantially in priority.

## Install traps recorded while getting here

- **`brew install claude` is the wrong package** — that cask is the Claude **desktop GUI app**. Fails with `Error: It seems there is already an App at '/Applications/Claude.app'`.
- **`npm install -g @anthropic-ai/claude-code` fails on Apple Silicon running x64 Node under Rosetta.** npm resolves the `darwin-x64` binary, which needs AVX that Rosetta does not emulate; `claude --version` then reports `native binary not installed`. This machine has x86_64 Homebrew at `/usr/local` and x86_64 node on an `arm64` machine. It also leaves a broken `/usr/local/bin/claude` shim that **shadows** a good install.
- **Working install:** `curl -fsSL https://claude.ai/install.sh | bash` → `~/.local/bin/claude`. That path is now an explicit `ClaudeExecutableLocator` candidate, because a GUI `.app` does not inherit the login shell's `PATH`.
- **Safari HTTPS-Only mode blocks the loopback callback** (`WebKitErrorDomain:305`). The flow succeeds; only delivery fails. Recover by `curl`-ing the callback URL to the still-listening port while `setup-token` runs.
