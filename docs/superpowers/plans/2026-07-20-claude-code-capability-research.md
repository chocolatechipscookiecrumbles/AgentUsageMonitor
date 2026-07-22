# Claude Code Capability Research and Integration Gate Plan

**Goal:** Determine whether Claude Code can provide privacy-safe, zero/near-zero-cost, user-meaningful personal usage/quota information before any real (non-preview) Claude Settings row, connection controller, refresh cycle, or notification behavior is built.

**Status:** Deferred research gate for any real connection controller, refresh cycle, or notification behavior. As of 2026-07-20, three things are authorized to explore/prototype — reusing Claude Code's own OAuth credential to call `api/oauth/usage` (primary source, personal/non-commercial use only, see "Personal, non-commercial OAuth reuse decision" below), the `statusLine`-sourced `rate_limits` reader (documented fallback, see "Authoritative-signal probe" below), and a narrow field-scoped local-JSONL reader for historical totals (see "Local usage-signal decision update" below) — but none by itself authorizes shipping a visible provider adapter or replacing `ClaudeCodePreviewSettingsView`. This follows the same gate structure as the [OpenCode capability research](2026-07-19-opencode-capability-research.md) and [GitHub Copilot capability probe](2026-07-19-github-copilot-capability-probe.md), per the roadmap's [later-provider-branches](2026-07-13-codex-daily-driver-roadmap.md#later-provider-branches) rule: normally sequenced after the Codex daily-driver release, opened early here only by explicit user direction and scoped to research, not implementation.

## Why this bar, not a lower one

[UsageProbe](../../../UsageProbe/README.md) — the existing Codex research harness — checks account limits and usage "**without starting a model turn**" and "cannot execute prompts, log out, or **consume reset credits**." Any Claude source has to be measured against that same zero-cost, read-only bar, not against "any way to see a number."

## Research findings — 2026-07-20

**No official *programmatic API* exists for a Pro/Max subscriber to pull personal-quota state on demand — but an official *passive* signal does, found during the 2026-07-20 follow-up below.** Every documented on-demand programmatic surface is either enterprise/org-admin-scoped or API-key/billing-scoped, not a personal subscription seat:

- **Claude Code Analytics API** and **Enterprise Analytics API** — return per-user usage, but require an org Admin API key / `read:analytics` scope created by a Primary Owner. Not available to an individual Pro/Max user monitoring their own seat.
- **Claude Console usage page / workspace spend limits** — API-key billing, not subscription-seat quota.
- **OpenTelemetry export** — real per-invocation metrics, but requires the user to configure an OTLP exporter and run a collector; it is not something already sitting on disk the way Codex's authenticated CLI session is, and it observes usage as it happens rather than answering "how much quota is left right now."

**The one built-in personal-usage surface, `/usage`, is TUI-only and is not guaranteed zero-cost.** Per Anthropic's own docs (code.claude.com/docs/en/costs):

- On Pro/Max/Team/Enterprise plans, `/usage` shows plan-limit bars — a breakdown of recent usage by skill/subagent/plugin/MCP server as a percentage of the account's rolling 5-hour and weekly windows — sourced from an undocumented internal "usage endpoint" that can itself be rate-limited (in which case `/usage` falls back to a locally cached snapshot up to 60 minutes old).
- That data is rendered in the interactive terminal UI. Nothing in the CLI reference or headless-mode docs exposes those plan-limit bars through `--output-format json`; the documented JSON fields (`total_cost_usd`, per-model cost) cover session API spend, not remaining subscription quota.
- Anthropic's docs state directly, under "Background token usage": *"Some commands like `/usage` may generate requests to check status... These background processes consume a small amount of tokens (typically under $0.04 per session) even without active interaction."* **This means the closest thing Claude Code has to `account/rateLimits/read` is not confirmed to be free.** A UsageProbe-style prober that shells out to `claude` to read `/usage` would not meet the same "cannot consume reset credits" guarantee this app makes for Codex.
- For Team/Enterprise seats specifically, Anthropic's docs also confirm the rolling 5-hour/weekly allowance "is shared with Claude chat and Cowork" — so even a perfect read would describe a shared pool, not a Claude-Code-only number, which needs careful product copy (an issue Codex does not have).

**Third-party tools (ccusage and similar) read local session transcripts, not a quota API.** `ccusage`, `claude-usage-tracker`, `claude-usage`, and several forks all work the same way: Claude Code writes one JSONL file per session under `~/.claude/projects/**/*.jsonl`, and these tools parse those files for per-message token counts, model names, and timestamps to estimate historical cost. This is architecturally the same shape as the OpenCode `opencode stats`/session-export source, and — per the 2026-07-20 decision below — is accepted on the same narrowed terms: it remains **historical consumption, not an authoritative remaining allowance**, and the source files sit alongside conversation content, project paths, and other session detail this app still does not read; a reader must extract only usage-metric fields and leave everything else untouched.

## Privacy and product boundary

Carried forward unmodified from the OpenCode gate and `AGENTS.md`'s existing UsageProbe boundary; the same reasoning applies to Claude Code's local state:

- Do not read `~/.claude/.credentials.json`, `~/.claude/settings.json` contents, shell environment variables, or any file containing prompts or conversation content. `~/.claude/projects/**/*.jsonl` may be read, but only for the narrow token/cost/model/timestamp fields described in "Local usage-signal decision update" below — never message content, tool inputs/outputs, or the full project directory name/path beyond what's needed to attribute a total.
- Do not require or store an Admin API key, `read:analytics` key, or any API/Console credential. This app monitors a personal seat, not an organization.
- Do not launch a background `claude -p` invocation, and do not treat any invocation that Anthropic's own docs describe as capable of consuming tokens as a zero-cost read, however small.
- Do not present historical token/cost totals (session-block figures, ccusage-style aggregates) as a remaining allowance, reset time, or plan-limit percentage. Those are different claims and this app already distinguishes them for Codex.
- Do not assume Claude Code's rolling-window allowance is Claude-Code-exclusive; if a source is later approved, product copy must account for the documented sharing with Claude chat/Cowork on Team/Enterprise seats and verify the Pro/Max case directly rather than assuming it matches.

## Candidate approaches and decisions

| Approach | What it could prove | Decision |
| --- | --- | --- |
| Parse `~/.claude/projects/**/*.jsonl` locally (the ccusage approach) | Estimated historical token/cost totals per session/day | **Accepted as the only currently viable local usage signal (revised 2026-07-20 — see "Local usage-signal decision update" below), narrowly scoped to token/cost/model/timestamp fields only.** It remains historical, not an authoritative remaining allowance — that is a product-copy constraint, not a privacy blocker. |
| Shell out to `claude -p "/usage" --output-format json` (or equivalent) on a timer | The same plan-limit bars a user sees interactively | **Rejected as currently specified.** Anthropic's own docs do not guarantee `/usage` is free of token cost, and nothing confirms the plan-limit bars are even reachable through `--output-format json` rather than being TUI-rendered only. Revisit only if Anthropic documents a zero-cost, scriptable output for this data. |
| Claude Code Analytics API / Enterprise Analytics API | Per-user usage and cost | **Rejected.** Requires an org Admin/Analytics API key; out of scope for a personal seat and out of scope for this app's no-credential boundary. |
| OpenTelemetry self-export | Real per-invocation token/cost metrics as they happen | **Deferred candidate, not a quota read.** Requires the user to already run an OTLP collector and would report consumption as it happens, not "how much is left" — a materially different product than the Codex quota display. Worth a separate, narrower research pass if a self-hosted metrics pipeline is ever in scope. |
| Read `rate_limits` from Claude Code's own `statusLine` JSON stdin | Exact 5-hour/weekly `used_percentage` + `resets_at`, sourced passively from real API response headers, not a token-count estimate | **Accepted — recommended primary path (2026-07-20, see "Authoritative-signal probe" below).** Official (`code.claude.com/docs/en/statusline`), zero additional cost, no credentials touched. This is the Codex-equivalent read the row below was waiting for; requires one-time user opt-in (a `statusLine` script) and only refreshes on active Claude Code use. |
| `GET https://api.anthropic.com/api/oauth/usage`, reusing Claude Code's own Keychain-stored OAuth credential | Session + weekly windows, per-model breakdown, plan tier, spend limits — richer than the statusLine signal | **Accepted for personal, non-commercial use only (revised 2026-07-20 — see "Personal, non-commercial OAuth reuse decision" below).** Anthropic's Legal and Compliance page still prohibits this in absolute terms; the user has knowingly accepted that risk for their own account on an undistributed personal build. Verified against this machine's real credential (`user:profile` scope present). Now the primary source; statusLine (Signal A) remains the documented fallback. |

## Gate before implementation

Create a Claude adapter with real connection, refresh, or usage behavior — replacing `ClaudeCodePreviewSettingsView` — only after all of the following are answered with direct, isolated evidence, mirroring the OpenCode gate:

1. ~~Anthropic documents a way to read personal Pro/Max plan-limit state (percentage used, reset time) that does not consume tokens or reset credits~~ — **satisfied 2026-07-20** by the `statusLine`-sourced `rate_limits` fields (see "Authoritative-signal probe" below), confirmed official and zero-cost the same way UsageProbe confirms Codex's `account/rateLimits/read` is non-consuming. **Implementation note:** the `ClaudeUsageBridge` script and `ClaudeRateLimitSnapshotReader` (see [statusLine usage bridge plan](2026-07-20-claude-statusline-usage-bridge.md)) implement and test Signal A end-to-end as an isolated component, with 13 Python tests and 8 Swift tests passing. No Settings UI, connection controller, or refresh cycle exists yet.
2. That source requires no admin/analytics API key. **Revised 2026-07-20** (see "Personal, non-commercial OAuth reuse decision" below): reading Claude Code's own Keychain credential to call `api/oauth/usage` is now explicitly authorized for this personal, undistributed build, superseding the earlier "no OAuth token our app requests or stores itself" language — this app reads, never stores, the token (Keychain remains the only store) and never requests a separate one. If the source is the field-scoped local JSONL reader instead, the implementation must still demonstrably never read conversation content, per "Local usage-signal decision update" below.
3. The product copy correctly scopes what the number means (Claude Code only vs. shared with Claude chat/Cowork) based on direct evidence for the plan type in use, not assumption.
4. ~~A single owner exists for the read cycle (mirroring `QuotaMonitor`'s ownership for Codex), with explicit teardown and no second polling source~~ — **satisfied 2026-07-20** by `ClaudeUsageMonitor` (see [usage monitor owner plan](2026-07-20-claude-usage-monitor-owner.md)), a `@MainActor` `ObservableObject` with explicit `start()`/`stop()` and `deinit`-cancelled polling, plus a tested, non-destructive `ClaudeStatusLineInstaller` for setup. Note the state model is deliberately simpler than `AgentConnectionState`/`ConfirmationState`: because the bridge only ever produces a last-known snapshot, there is no "live/confirmed" state to distinguish, only available-or-not. `ClaudeStatusLineInstaller`'s production `bridgeDirectory` path is not yet resolvable — `ClaudeUsageBridge/` is not bundled into the signed `.app` — so this is real, tested code not yet reachable end-to-end by a user.
5. If no zero-cost source exists, the fallback is an explicit, permanent "not available" state (as `ClaudeCodePreviewSettingsView` already shows) — not a best-effort estimate presented as a quota.

Criteria 1, 2, and 4 are now satisfied by the statusLine bridge and `ClaudeUsageMonitor`; criteria 3 and 5 (product-copy accuracy, a visible "not available" fallback) remain UI-layer work with no Settings surface built yet. Until all five are met, Claude Code remains a static preview: no connection controller wired to product UI, no refresh cycle driving a view, no notifications, no usage read reachable by an end user.

**Credential-method update — 2026-07-21.** Criterion 2's OAuth-reuse concession is no longer the *only* option. Tier 1 now has **two co-equal, user-selectable credential methods**, mirroring Codex's browser/CLI sign-in pair (see [credential methods plan](2026-07-21-claude-oauth-web-login-provider.md)):

- **(a) Browser sign-in** via Anthropic's own `claude setup-token`, which issues a long-lived token *to this app*. This is officially sanctioned, needs no reading of Claude Code's credential, raises **no Keychain ACL prompt**, and never calls `/v1/oauth/token` from this app.
- **(b) Claude Code credentials** — the existing Keychain read, retained as the zero-setup option, now reachable only by an explicit user action carrying a disclosure of what it grants.

This materially narrows criterion 2's ToS exposure: method (a) involves no credential reuse at all, so the personal-build concession is now a fallback posture rather than the design's foundation. A self-run PKCE flow was proven feasible but **deliberately not shipped** — it would reuse Claude Code's `client_id` (misleading consent screen); see [spike findings](2026-07-21-claude-oauth-web-login-spike-findings.md). `ClaudeConnectionController` and `ClaudeSignInView` exist and are tested (93 Claude tests), but are **not yet wired into `AgentsSettingsView`**, so criterion 3/5 UI work and end-user reachability still stand open.

## Authoritative-signal probe: statusLine vs. OAuth endpoint — 2026-07-20

User direction: verify the `/usage` token-cost claim, model its cost at a 2-minute refresh cadence against Pro/Max pricing, and probe two candidate authoritative (non-estimate) signals surfaced during that research — Claude Code's own `statusLine` JSON and the `api.anthropic.com/api/oauth/usage` endpoint CodexBar uses — for accuracy and user-experience impact, including whether the OAuth path is "just a browser sign-in" or something harder.

### `/usage` token cost: confirmed as a real claim, but sources conflict on magnitude

Anthropic's own docs state it twice, independently (`code.claude.com/docs/en/costs`, and quoted verbatim in [GitHub issue #33978](https://github.com/anthropics/claude-code/issues/33978)): *"Some commands like `/usage` may generate requests to check status... These background processes consume a small amount of tokens (typically under $0.04 per session) even without active interaction."* CodexBar's own docs claim the opposite for its CLI-PTY `/usage`-parsing fallback ("Token cost: None"). Neither source gives exact per-invocation numbers, and "per session" is ambiguous (once per Claude Code session vs. per `/usage` call). This is a **primary-source vs. secondary-tool conflict that remains unresolved by documentation alone** — the finding below makes it moot for this app's design either way.

**Cost modeling at a 2-minute refresh cadence**, using Anthropic's own worst-case figure ($0.04/check) as a notional API-equivalent value (subscribers aren't billed per check, but Anthropic states the tokens genuinely count against the account, so this is the closest available proxy for scale):

| Polling pattern | Checks/month | Notional cost/month | vs. plan price |
| --- | --- | --- | --- |
| Every 2 min, 24/7 | ~21,600 | ~$864 | 4.3× a $200/mo Max 20x plan |
| Every 2 min, 8h/day, 22 workdays | ~5,280 | ~$211 | 10.6× a $20/mo Pro plan; ~2× a $100/mo Max 5x plan |

Even restricted to working hours, a `/usage`-based poller could notionally consume several times a subscriber's entire monthly plan value just checking status, before any real coding. This confirms the earlier "hold the zero-cost line" decision regardless of which cost figure is correct, and motivated probing the two signals below instead of resolving the `/usage` cost dispute further.

### Signal A — `rate_limits` in Claude Code's `statusLine` JSON (recommended)

Per `code.claude.com/docs/en/statusline`, every time Claude Code renders its status line — after a real turn the user already initiated — it writes JSON to the configured script's stdin, including:

```
rate_limits.five_hour.used_percentage   (0–100, exact float)
rate_limits.five_hour.resets_at         (Unix epoch seconds)
rate_limits.seven_day.used_percentage
rate_limits.seven_day.resets_at
```

This is populated passively from the same `anthropic-ratelimit-unified-*` response headers Anthropic returns on every real API call Claude Code makes — not a new request, not an estimate derived from token counts. The docs note it "appears only for Claude.ai subscribers (Pro/Max) after the first API response in the session" and each window "may be independently absent."

- **Cost:** Zero. No new request; it rides on turns the user was already going to make.
- **Accuracy:** High for the two fields it covers — an exact float from Anthropic's own enforcement layer, not a locally-estimated dollar figure. Narrower in scope than the OAuth endpoint: no per-model breakdown, no plan tier, no spend-limit data — just the two rolling-window percentages and reset times.
- **Freshness:** Only as fresh as the user's last Claude Code turn. Absent entirely before the first API call in a session, and does not update while the user is away from Claude Code — this app would show a "last known" snapshot the same way it already caches Codex quota data, not a live-anytime read.
- **User experience:** No browser, no sign-in, no consent screen. Requires one-time setup: the user (or an installer we ship) adds/merges a `statusLine.command` entry in `~/.claude/settings.json` that writes the `rate_limits` fields to a small local file this app reads. Claude Code supports only one `statusLine` hook, so if the user already runs a custom one, setup must merge with it rather than silently replace it. Cross-device/cross-session freshness is local-only — a Claude Code session on another machine won't update this machine's file.
- **Privacy:** Clean. No credentials, no conversation content, no new network request from this app.

### Signal B — `GET https://api.anthropic.com/api/oauth/usage` (rejected — policy, not complexity)

CodexBar's docs describe this as an official Anthropic endpoint (`user:profile` OAuth scope) returning session + weekly windows, per-model breakdown, plan tier, and spend limits — richer data than Signal A. Mechanically, obtaining an OAuth token this way **is** "just a browser sign-in": Claude Code's own login is a standard 4-step OAuth 2.0 + PKCE flow (`claude` starts a local callback listener, opens the browser to Anthropic's consent page, receives a redirect with an authorization code, exchanges it for access/refresh tokens) — about 10 seconds, no special complexity, the same flow `claude login` already uses.

The reason this path is closed isn't engineering difficulty — it's policy, confirmed directly on Anthropic's own site:

- **Anthropic does not offer third-party OAuth client registration at all.** Claude Code's client ID is hard-coded to that one application; there is no public developer flow to register a distinct client ID for another app the way, e.g., "Sign in with Google" works for arbitrary third parties.
- **Anthropic's official Legal and Compliance page** (`code.claude.com/docs/en/legal-and-compliance`, updated 2026-02-19) states directly: *"OAuth authentication is intended exclusively for purchasers of Claude Free, Pro, Max, Team, and Enterprise subscription plans and is designed to support ordinary use of Claude Code and other native Anthropic applications... Anthropic does not permit third-party developers to offer Claude.ai login or to route requests through Free, Pro, or Max plan credentials on behalf of their users. Anthropic reserves the right to take measures to enforce these restrictions and may do so without prior notice."*
- This is actively enforced, not theoretical: reporting from February 2026 (The Register, WinBuzzer, Gigazine) confirms Anthropic deployed server-side blocks against exactly this pattern, and named tools (Auto-Claude, Goose, OpenCode) were forced to drop OAuth reuse and switch to standard API keys as a result.
- The credential-reuse fallback CodexBar also documents (reading Claude Code's own Keychain-stored token) was already rejected on privacy grounds in this doc's original boundary — this policy finding rejects the "build our own OAuth client instead" alternative too, closing off Signal B entirely rather than leaving it as a future direction.

**2026-07-20 original decision (superseded below): Signal B rejected outright**, on the reasoning that a product-owned OAuth client mirroring the Copilot pattern wasn't available to Claude the way it is to Copilot's device-flow route. **This was revised the same day** — see "Personal, non-commercial OAuth reuse decision" further down: for this specific, undistributed personal build, the user has explicitly accepted the ToS risk of reusing Claude Code's own credential rather than obtaining a separate client (which remains impossible). Signal B is now the primary source; Signal A (statusLine) is the documented fallback tier, not a replacement.

### Net effect on this plan

Both signals are used, not one instead of the other: Signal B (OAuth) is the primary live source when a usable credential exists; Signal A (statusLine) is the fallback when OAuth is unavailable, per the [Claude usage provider plan](2026-07-20-claude-usage-provider.md). The field-scoped local-JSONL reader remains a third, lower-priority source for historical token/cost totals neither signal provides.

## Local usage-signal decision update — 2026-07-20

User direction: since no zero-cost official API exists (per the gate above) and `/usage` is not confirmed free, local-JSONL parsing is accepted as the only currently viable usage signal — with exploration starting from the narrowest safe scope, not the full ccusage-style transcript reader:

- A reader may extract only `usage` token-count fields (`input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`), model name, and timestamp per JSONL line. It must not read, log, or retain `message.content`, tool inputs/outputs, or any field not needed for a token/cost total.
- The credential/config prohibitions above are unchanged: `.credentials.json` and `settings.json` contents stay off-limits regardless of this update.
- This remains historical consumption, not a remaining allowance or reset time — any UI built on it must label it as an estimate, as plainly as UsageProbe's "experimental" label does for Codex.
- Explore the narrow field-scoped reader first; broaden scope only if it cannot produce a meaningful number.

Before implementation code is written, the following need direct evidence, not assumption:

1. Can the reader be implemented as a streaming line-by-line JSON field-picker that never materializes `message.content`, `message.role`-adjacent text, or tool inputs/outputs in memory, not merely one that discards them after parsing the full line?
2. Does Claude Code's JSONL schema keep token-usage fields structurally separate from message content in a way a field-picker can rely on across versions, or could a schema change silently pull content into the read path? If so, what detects that drift before it ships?
3. Does reading files that live inside `~/.claude/projects/<project-name>/...` — where the directory name is a working-directory-derived project identifier — need any additional handling of that identifier (e.g., excluding it from anything persisted or displayed) even though file contents are field-filtered?
4. What single component owns this read cycle, mirroring `QuotaMonitor`'s ownership for Codex, and what is its teardown/refresh-cadence story?

This unblocks design/prototyping of the field-scoped reader. It does not by itself authorize shipping a visible Claude usage UI or replacing `ClaudeCodePreviewSettingsView` — the full gate above (owner, product-copy accuracy, "not available" fallback) still applies before that.

## Personal, non-commercial OAuth reuse decision — 2026-07-20

User direction, reviewed against a similar personal tool ([Javis603/token-monitor](https://github.com/Javis603/token-monitor)) that combines OAuth and `/usage`: since this app is personal and not distributed commercially, the user has explicitly and knowingly accepted the ToS/policy risk of Signal B for their own account, and directed the app to read Claude Code's own already-issued OAuth credential (from macOS Keychain, service `Claude Code-credentials`) to call `GET https://api.anthropic.com/api/oauth/usage` directly.

This does not change the underlying facts recorded above — worth restating plainly rather than re-litigating on every future read of this doc:

- Anthropic's Legal and Compliance page draws no personal-use/non-commercial exception; the restriction is stated in absolute terms. The user is accepting that risk personally, for their own account, not on behalf of other users — this app is not distributed and does not offer "Claude.ai login" to anyone but its own author.
- This also reverses the separate privacy-boundary objection to reading Claude Code's stored credential (previously rejected alongside OpenCode's `auth.json` and Copilot's persisted-token pattern): the user has explicitly authorized this app to read its **own** already-authenticated Claude Code Keychain entry, for the user's own account, which is a materially different posture than silently reading another user's or another install's credential.
- **Verified against this machine's real credential** (metadata only — no token value was ever printed, logged, or persisted): `Claude Code-credentials` in the login Keychain holds a `claudeAiOauth` object with `accessToken`, `refreshToken` (both opaque, ~108-char strings), `expiresAt`/`refreshTokenExpiresAt` (Unix **milliseconds**, not seconds — note the unit difference from the statusLine bridge's second-based timestamps), `scopes` (this machine's token includes `user:profile`, matching CodexBar's documented requirement that `user:profile`-scoped tokens can call the usage endpoint), `subscriptionType` (e.g. `"pro"`), and `rateLimitTier`.
- Security requirements from the reviewed plan remain binding regardless of the ToS decision: never persist the access/refresh token outside Keychain, never log it, never include it in error reports, use a Keychain prompt policy that never interrupts background/menu-open refreshes, and treat a denied/unavailable Keychain read as "fall through to the statusLine source," not a hard failure.

**Revised decision:** Signal B is **accepted for this personal build only**, as the primary source, ahead of the statusLine signal. Implementation proceeds per the [Claude usage provider plan](2026-07-20-claude-usage-provider.md), which also keeps the existing statusLine bridge (Signal A) as the documented fallback tier, exactly as the gate below already established it.

**2026-07-20 implementation note:** `ClaudeUsageCollector` (see the usage provider plan) implements and tests the full OAuth → statusLine → cache order end-to-end — `ClaudeKeychainCredentialStore`, `ClaudeOAuthUsageSource`, `ClaudeUsageCache`, and the coordinator itself, 25 new Swift tests, 52 total passing, zero regressions. Both the Keychain credential shape and the live `GET /api/oauth/usage` response shape were verified against one real, read-only call to this account (no token or identity data ever printed, logged, or persisted) — the real schema differs from `claude_probe_plan`'s assumed field names in several places (`utilization` not `used_percent`, ISO 8601 microsecond timestamps not Unix epoch, no account-identity field in the response at all), documented in the provider plan so future readers trust the verified schema over the original plan document. Tier 3 (user-authorized CLI `/usage` PTY probe) and all Settings UI remain deferred, named explicitly, not silently dropped.

## Sources

- [Claude Code — Manage costs effectively](https://code.claude.com/docs/en/costs) — `/usage` plan-limit bars, background token usage on `/usage`, Analytics/Enterprise API scope, OpenTelemetry.
- [Claude Code — Run Claude Code programmatically (headless mode)](https://code.claude.com/docs/en/headless) — `-p`/`--output-format json` fields (`total_cost_usd`, session metadata); no plan-quota field documented.
- [Models, usage, and limits in Claude Code — Claude Help Center](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code) — `/cost` vs. `/usage` distinction.
- [ccusage](https://ccusage.com/) / [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) — reference implementation of the local-JSONL approach being rejected as a quota source.
- [haasonsaas/claude-usage-tracker](https://github.com/haasonsaas/claude-usage-tracker), [aarora79/claude-code-usage-analyzer](https://github.com/aarora79/claude-code-usage-analyzer) — same JSONL-parsing pattern, corroborating it is the community-standard (not official) approach.
- [Existing UsageProbe safety boundary](../../../UsageProbe/README.md#safety-boundary) — the zero-cost bar this research is measured against.
- [OpenCode capability research](2026-07-19-opencode-capability-research.md) — precedent gate structure and privacy-boundary language reused here.
- [Claude Code — Customize your status line](https://code.claude.com/docs/en/statusline) — official `rate_limits.five_hour`/`seven_day` JSON fields (Signal A), source of the recommended primary path.
- [CodexBar — Claude usage data collection docs](https://github.com/steipete/CodexBar/blob/main/docs/claude.md) — documents the `api/oauth/usage` endpoint (Signal B), its OAuth scope, and the CLI-PTY/web-cookie fallbacks this app rejects on privacy grounds independent of the policy finding below.
- [Claude Code — Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance) — primary-source policy text closing Signal B: consumer OAuth tokens are restricted to Claude Code/Claude.ai, with reserved enforcement rights.
- [GitHub issue #33978 — Built-in Usage Analytics Command](https://github.com/anthropics/claude-code/issues/33978) — corroborates the `/usage` background-token-cost claim verbatim from Anthropic's docs.
- Reporting on the February 2026 OAuth policy enforcement: [The Register](https://www.theregister.com/2026/02/20/anthropic_clarifies_ban_third_party_claude_access/), [WinBuzzer](https://winbuzzer.com/2026/02/19/anthropic-bans-claude-subscription-oauth-in-third-party-apps-xcxwbn/) — corroborate active server-side enforcement against third-party OAuth reuse (Auto-Claude, Goose, OpenCode named as affected).
