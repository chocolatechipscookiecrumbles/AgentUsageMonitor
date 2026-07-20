# OpenCode Capability Research and Integration Gate Plan

**Goal:** Determine whether OpenCode can provide privacy-safe, user-meaningful connection or usage information before any OpenCode Settings row, selector item, or background behavior is built.

**Status:** Deferred research gate for any OpenCode adapter, Settings UI, or connection behavior. As of 2026-07-20, a narrow field-scoped local usage-signal reader is authorized to explore/prototype under "Local usage-signal decision update" below; it does not by itself authorize shipping a visible provider, selector entry, or Settings preview.

## Research findings — 2026-07-19

- OpenCode is a multi-provider coding-agent host, not a single account service. Its provider guide says it supports many providers and stores provider API keys added through `/connect` in `~/.local/share/opencode/auth.json`.
- An OpenCode TUI runs a server, and `opencode serve` can run another HTTP server. The documented `GET /provider` response contains provider metadata and a `connected` provider-ID list. The API does not describe a personal allowance, remaining quota, plan, or reset-time value.
- The server can be password-protected and is intentionally an OpenAPI surface that can modify sessions, provider OAuth state, configuration, and authentication. This app must not scan localhost, start a server, or assume an unauthenticated local endpoint is available.
- `opencode stats` reports historic token/cost statistics for OpenCode sessions. That is consumption history, not a provider-authoritative remaining allowance, and can include activity for several underlying providers.
- OpenCode Console’s documented Usage API exports organization billing records as CSV only with a service-account key. It can contain member email, service-account information, token counts, model/provider data, and cost. It is unsuitable for a personal menu-bar quota monitor and conflicts with this app’s no-credential/no-account-identity boundary.

## Privacy and product boundary

- Do not read `~/.local/share/opencode/auth.json`, OpenCode configuration, `.env` files, shell environment variables, browser cookies, prompts, source paths, or local databases. Session exports / `opencode stats` output may be read, but only for the narrow token/cost/model/timestamp fields described in "Local usage-signal decision update" below — never message content, tool inputs/outputs, or unrelated fields.
- Do not launch `opencode`, `opencode serve`, `opencode web`, or any discovery process. Do not scan ports or make unsolicited localhost requests.
- Do not store an OpenCode URL, server password, service-account key, provider key, account identity, usage history, or provider configuration.
- Do not treat a host-level provider list or historic session statistics as a single provider’s quota, plan, connection, or reset schedule.

## Candidate approaches and decisions

| Approach | What it could prove | Decision |
| --- | --- | --- |
| User-started, explicitly configured OpenCode server; read-only `GET /provider` | A selected OpenCode instance reports particular connected provider IDs. | **Deferred candidate.** Requires a future UX, explicit endpoint/password consent, connection lifecycle, and proof that the request cannot mutate state. It still cannot provide quota information. |
| Read `auth.json`, config, environment, or session cache | Credentials/configuration or historic sessions. | **Rejected.** These sources can contain secrets, identity, prompts, paths, and multi-provider data. |
| `opencode stats` or session export | Aggregate historic token/cost statistics. | **Accepted as the only currently viable local usage signal (revised 2026-07-20 — see "Local usage-signal decision update" below), narrowly scoped to token/cost/model/timestamp fields only.** It remains historical, provider-mixed, and not a provider-authoritative allowance — that limitation is a product-copy constraint, not a privacy blocker. |
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

## Local usage-signal decision update — 2026-07-20

User direction: since no documented OpenCode API describes a personal allowance, remaining quota, plan, or reset time at all, `opencode stats`/session-export data is accepted as the only currently viable local usage signal, on the following narrowed terms — reached the same way as the parallel decision in the [Claude Code capability research](2026-07-20-claude-code-capability-research.md):

- A reader may extract only token-count, cost, model, and timestamp fields from `opencode stats` output or a session export. It must not read, log, or retain message/prompt content, tool inputs/outputs, file paths beyond a session's own top-level identifier, or any field not needed for a token/cost total.
- This does **not** reopen `auth.json`, OpenCode configuration, `.env` files, shell environment variables, browser cookies, or local databases — those remain fully rejected per the table above; this update touches only the stats/session-export row.
- Because OpenCode is explicitly multi-provider, an accepted reader must not attribute mixed-provider stats to a single provider's quota without the same evidence the `GET /provider` row already requires (connected provider ID). Until that attribution is proven, present totals as "OpenCode host activity," not any one provider's usage.
- The result is still consumption history, not a remaining allowance — every product surface built on this data must say so as plainly as UsageProbe's "experimental" label does for Codex, per the existing `Do not treat a host-level provider list or historic session statistics as a single provider's quota, plan, connection, or reset schedule` boundary bullet above, which stands unchanged.
- Explore the narrow, field-scoped reader first (per this update) before considering the fuller `opencode stats` surface; expand scope only if the narrow reader cannot produce a meaningful number.

This unblocks further design/prototyping of a field-scoped local usage reader. It does not by itself satisfy the "Gate before implementation" above — an adapter or Settings UI still needs a single lifecycle owner, explicit teardown, and evidence for local-server stop/start and failed reads before it ships.

## Sources

- [OpenCode Server documentation](https://opencode.ai/docs/server/) — local server lifecycle, `/provider`, and wider mutable API surface.
- [OpenCode Providers documentation](https://opencode.ai/docs/providers/) — multi-provider model and `auth.json` credential location.
- [OpenCode CLI documentation](https://dev.opencode.ai/docs/cli/) — historic session statistics and exports.
- [OpenCode Console Usage API](https://console.opencode.ai/guides/usage) — service-account CSV export and its billing fields.
