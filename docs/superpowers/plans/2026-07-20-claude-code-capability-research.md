# Claude Code Capability Research and Integration Gate Plan

**Goal:** Determine whether Claude Code can provide privacy-safe, zero/near-zero-cost, user-meaningful personal usage/quota information before any real (non-preview) Claude Settings row, connection controller, refresh cycle, or notification behavior is built.

**Status:** Deferred research gate for any real connection controller, refresh cycle, or notification behavior. As of 2026-07-20, a narrow field-scoped local usage-signal reader is authorized to explore/prototype under "Local usage-signal decision update" below; it does not by itself authorize shipping a visible provider adapter or replacing `ClaudeCodePreviewSettingsView`. It follows the same gate structure as the [OpenCode capability research](2026-07-19-opencode-capability-research.md) and [GitHub Copilot capability probe](2026-07-19-github-copilot-capability-probe.md), per the roadmap's [later-provider-branches](2026-07-13-codex-daily-driver-roadmap.md#later-provider-branches) rule: normally sequenced after the Codex daily-driver release, opened early here only by explicit user direction and scoped to research, not implementation.

## Why this bar, not a lower one

[UsageProbe](../../../UsageProbe/README.md) — the existing Codex research harness — checks account limits and usage "**without starting a model turn**" and "cannot execute prompts, log out, or **consume reset credits**." Any Claude source has to be measured against that same zero-cost, read-only bar, not against "any way to see a number."

## Research findings — 2026-07-20

**No official personal-quota API exists for a Pro/Max subscriber running Claude Code locally.** Every documented programmatic usage surface is either enterprise/org-admin-scoped or API-key/billing-scoped, not a personal subscription seat:

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
| Wait for an official, documented, zero-cost personal usage/quota endpoint | A true Codex-equivalent read | **Future research direction.** This is the only approach that would clear the existing UsageProbe bar without a compromise. No such endpoint is documented today. |

## Gate before implementation

Create a Claude adapter with real connection, refresh, or usage behavior — replacing `ClaudeCodePreviewSettingsView` — only after all of the following are answered with direct, isolated evidence, mirroring the OpenCode gate:

1. Anthropic documents a way to read personal Pro/Max plan-limit state (percentage used, reset time) that does not consume tokens or reset credits, confirmed the same way UsageProbe confirms Codex's `account/rateLimits/read` is non-consuming.
2. That source requires no admin/analytics API key and no `.credentials.json` read, and — if it is the field-scoped local JSONL reader rather than an official API — the implementation demonstrably never reads conversation content, per "Local usage-signal decision update" below.
3. The product copy correctly scopes what the number means (Claude Code only vs. shared with Claude chat/Cowork) based on direct evidence for the plan type in use, not assumption.
4. A single owner exists for the read cycle (mirroring `QuotaMonitor`'s ownership for Codex), with explicit teardown and no second polling source.
5. If no zero-cost source exists, the fallback is an explicit, permanent "not available" state (as `ClaudeCodePreviewSettingsView` already shows) — not a best-effort estimate presented as a quota.

Until gate criteria 1–2 are met, Claude Code remains a static preview: no connection controller, no refresh cycle, no notifications, no usage read of any kind.

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

## Sources

- [Claude Code — Manage costs effectively](https://code.claude.com/docs/en/costs) — `/usage` plan-limit bars, background token usage on `/usage`, Analytics/Enterprise API scope, OpenTelemetry.
- [Claude Code — Run Claude Code programmatically (headless mode)](https://code.claude.com/docs/en/headless) — `-p`/`--output-format json` fields (`total_cost_usd`, session metadata); no plan-quota field documented.
- [Models, usage, and limits in Claude Code — Claude Help Center](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code) — `/cost` vs. `/usage` distinction.
- [ccusage](https://ccusage.com/) / [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) — reference implementation of the local-JSONL approach being rejected as a quota source.
- [haasonsaas/claude-usage-tracker](https://github.com/haasonsaas/claude-usage-tracker), [aarora79/claude-code-usage-analyzer](https://github.com/aarora79/claude-code-usage-analyzer) — same JSONL-parsing pattern, corroborating it is the community-standard (not official) approach.
- [Existing UsageProbe safety boundary](../../../UsageProbe/README.md#safety-boundary) — the zero-cost bar this research is measured against.
- [OpenCode capability research](2026-07-19-opencode-capability-research.md) — precedent gate structure and privacy-boundary language reused here.
