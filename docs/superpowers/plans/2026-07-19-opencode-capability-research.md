# OpenCode Capability Research and Integration Gate Plan

**Goal:** Determine whether OpenCode can provide privacy-safe, user-meaningful connection or usage information before any OpenCode Settings row, selector item, or background behavior is built.

**Status:** Deferred research gate. This plan authorizes no application implementation.

## Research findings — 2026-07-19

- OpenCode is a multi-provider coding-agent host, not a single account service. Its provider guide says it supports many providers and stores provider API keys added through `/connect` in `~/.local/share/opencode/auth.json`.
- An OpenCode TUI runs a server, and `opencode serve` can run another HTTP server. The documented `GET /provider` response contains provider metadata and a `connected` provider-ID list. The API does not describe a personal allowance, remaining quota, plan, or reset-time value.
- The server can be password-protected and is intentionally an OpenAPI surface that can modify sessions, provider OAuth state, configuration, and authentication. This app must not scan localhost, start a server, or assume an unauthenticated local endpoint is available.
- `opencode stats` reports historic token/cost statistics for OpenCode sessions. That is consumption history, not a provider-authoritative remaining allowance, and can include activity for several underlying providers.
- OpenCode Console’s documented Usage API exports organization billing records as CSV only with a service-account key. It can contain member email, service-account information, token counts, model/provider data, and cost. It is unsuitable for a personal menu-bar quota monitor and conflicts with this app’s no-credential/no-account-identity boundary.

## Privacy and product boundary

- Do not read `~/.local/share/opencode/auth.json`, OpenCode configuration, `.env` files, shell environment variables, browser cookies, session exports, prompts, source paths, or local databases.
- Do not launch `opencode`, `opencode serve`, `opencode web`, or any discovery process. Do not scan ports or make unsolicited localhost requests.
- Do not store an OpenCode URL, server password, service-account key, provider key, account identity, usage history, or provider configuration.
- Do not treat a host-level provider list or historic session statistics as a single provider’s quota, plan, connection, or reset schedule.

## Candidate approaches and decisions

| Approach | What it could prove | Decision |
| --- | --- | --- |
| User-started, explicitly configured OpenCode server; read-only `GET /provider` | A selected OpenCode instance reports particular connected provider IDs. | **Deferred candidate.** Requires a future UX, explicit endpoint/password consent, connection lifecycle, and proof that the request cannot mutate state. It still cannot provide quota information. |
| Read `auth.json`, config, environment, or session cache | Credentials/configuration or historic sessions. | **Rejected.** These sources can contain secrets, identity, prompts, paths, and multi-provider data. |
| `opencode stats` or session export | Aggregate historic token/cost statistics. | **Rejected as a quota source.** It is historical, provider-mixed, and can expose sensitive session data. |
| OpenCode Console Usage API | Organization billing export. | **Rejected.** It requires a service-account key and can expose other members’ emails and costs; it is not a personal allowance API. |
| Direct official API for the underlying selected provider | Provider-specific authenticated quota or usage, if that provider documents it. | **Future research direction.** Evaluate separately per provider under its own privacy/capability plan. |

## Gate before implementation

Create an OpenCode adapter or Settings UI only after all of the following are answered with direct, isolated evidence:

1. The user can deliberately choose one running local instance without background discovery or a stored secret.
2. A documented read-only endpoint provides an identity-safe connection signal that has clear semantics when the server is unavailable, password-protected, or hosting multiple providers.
3. The product language distinguishes OpenCode-host connectivity from provider-account connection and never calls historical tokens a remaining quota.
4. Any remote/provider request is official, user-authorized, credential-safe, and supplies a stable allowance/usage contract appropriate for the monitored provider.
5. The lifecycle has one owner, no second quota scheduler, explicit teardown, and acceptance evidence for local-server stop/start, failed reads, and multi-provider selection.

Until then, OpenCode is not a visible provider, an Agents selector entry, or a Settings preview. The Codex/Claude preview UI plan remains independent from this research gate.

## Sources

- [OpenCode Server documentation](https://opencode.ai/docs/server/) — local server lifecycle, `/provider`, and wider mutable API surface.
- [OpenCode Providers documentation](https://opencode.ai/docs/providers/) — multi-provider model and `auth.json` credential location.
- [OpenCode CLI documentation](https://dev.opencode.ai/docs/cli/) — historic session statistics and exports.
- [OpenCode Console Usage API](https://console.opencode.ai/guides/usage) — service-account CSV export and its billing fields.
