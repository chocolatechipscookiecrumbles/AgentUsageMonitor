# Claude usage-endpoint rate safety (Workstream G, Step 1b)

**Question:** How often can the app read Claude usage over the network without
triggering endpoint/rate-limit problems, and what is the safe automatic floor?

**Method / honesty note.** A *controlled live probe* — deliberately hammering the
endpoint at varying frequencies with the user's real token to observe 429
behavior — was **not** run. It cannot be run from the development sandbox (no
access to the user's Keychain OAuth token, wrong process context), and running
it against the user's real account risks putting that account into a sticky
rate-limit state. Instead this is grounded in (1) direct inspection of the
request the app makes and (2) documented community evidence for this exact
endpoint. Both converged on a concrete, fixable cause.

## The endpoint

`GET https://api.anthropic.com/api/oauth/usage` — the same endpoint Claude Code
itself polls to show its status-line usage. Our request
(`ClaudeOAuthUsageSource`) sends `Authorization: Bearer <token>` and
`anthropic-beta: oauth-2025-04-20`, with a 10s timeout, on an ephemeral session.

## Findings

1. **The real cause of endpoint trouble was a missing header, not the interval.**
   The community has found that `/api/oauth/usage` places callers **without** a
   `User-Agent: claude-code/<version>` header into an **aggressively
   rate-limited bucket** that returns persistent `429`s, and that the endpoint
   **does not recover if hammered** (retries at 30 → 60 → 120 → 240 → 300s all
   return 429, then it stays 429 for the session). Our request was **missing the
   `User-Agent`**, so every automatic read risked the aggressive bucket — which
   would present as Claude usage intermittently falling back to the statusLine
   or cache. See sources.

2. **429 was swallowed and never obeyed.** The collector used `try?`, so a 429
   was indistinguishable from any other failure and the server's `Retry-After`
   was never read — the app would just try again at the next poll.

## Decisions (implemented)

- **Send the required headers** (`ClaudeOAuthUsageSource`): `User-Agent:
  claude-code/<version>` (static `ClaudeUsageUserAgent.value`, injectable and
  easy to bump) plus `Content-Type: application/json`. This is the primary fix
  and keeps the app out of the aggressive bucket.
- **Obey the server on 429** (`ClaudeUsageCollector`): a 429 now becomes
  `ClaudeOAuthError.rateLimited(retryAfter:)`; the collector parses `Retry-After`
  (seconds or HTTP-date) and **skips the networked OAuth read until then**,
  serving the local statusLine/cache meanwhile. When the server sends no
  `Retry-After`, it backs off 15 minutes. This makes the app self-correct even
  if any interval assumption is wrong — it cannot compound the limit.
- **Automatic network floor stays 5 minutes** (`ClaudeRefreshCadence.networkFloor`).
  At most 12 reads/hour is negligible for a lightweight status GET, and Claude
  Code polls this same endpoint routinely; with the correct `User-Agent` and the
  429 back-off, 5 minutes is safe. There is no user-visible benefit to reading
  Claude usage more often than that, so the floor is not lowered.

## ToS boundary

Sending the `claude-code/<version>` User-Agent extends the impersonation the
personal build already performs (it reuses Claude Code's own Keychain
credential). This stays within the **personal, non-commercial** boundary the
project documents; Anthropic's ToS still prohibits it in absolute terms. Do not
ship this commercially.

## Limitations / follow-ups

- The exact rate-limit numbers are community-reported, not measured here.
- The `User-Agent` version is a **static constant**. Evidence indicates the
  *presence* of a `claude-code` agent is what matters, not the exact version; if
  Anthropic begins validating the version, bump `ClaudeUsageUserAgent.value`
  (or resolve the installed Claude Code version at runtime).
- If, after these changes, 429s still appear in practice, the next step is to
  capture the response headers from a real signed-app read (which the back-off
  now surfaces) and adjust from measured behavior.

## Sources

- [OAuth usage API (/api/oauth/usage) returns persistent 429 rate limit — anthropics/claude-code #31021](https://github.com/anthropics/claude-code/issues/31021)
- [/api/oauth/usage endpoint aggressively rate limits — anthropics/claude-code #31637](https://github.com/anthropics/claude-code/issues/31637)
- [Anthropic OAuth token refresh silently fails with 429 — earendil-works/pi #4621](https://github.com/earendil-works/pi/issues/4621)
- [Rate Limits API — Claude Platform Docs](https://platform.claude.com/docs/en/manage-claude/rate-limits-api)
