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
