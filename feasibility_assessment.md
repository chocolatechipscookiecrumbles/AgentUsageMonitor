# Feasibility assessment

Verified 12 July 2026.

## Decision

The product is feasible as a personal, independently distributed macOS application. A useful MVP can combine provider-reported limits where obtainable with clearly separated local analytics.

It is **not yet feasible to promise a low-maintenance commercial or Mac App Store product with authoritative quota data for all three providers**. GitHub offers a documented personal billing API. Codex and Claude expose usage to users, and open-source applications demonstrate working collection strategies, but neither provider currently documents a general-purpose personal-subscription quota API for third-party applications.

The project should therefore use capability-based language:

- GitHub Copilot: supported billing integration, subject to confirming what a Student entitlement returns.
- OpenAI Codex: experimental personal quota integration plus supported local analytics.
- Claude: experimental personal quota integration plus supported local analytics.
- Widgets and Watch: cached summaries only; never direct provider access.

## Evidence matrix

| Provider | Provider-reported values exist | Documented personal third-party API | Recommended first probe | Product status |
|---|---:|---:|---|---|
| GitHub Copilot | Yes | Yes, for usage billed to a personal account | GitHub REST billing usage with a minimum-scope token | Supported after Student-plan validation |
| OpenAI Codex | Yes | No general personal quota API found | Existing Codex login and provider-owned status/usage mechanisms | Experimental |
| Claude | Yes | No personal Pro/Max quota API found | Existing Claude Code login and provider-owned status mechanism | Experimental |
| Local activity | Yes, for activity recorded on this Mac | Local files/tools | Native parsers or `ccusage`-compatible output | Supported, but not account-wide quota |

### Sources

- [GitHub REST billing usage](https://docs.github.com/en/rest/billing/usage) documents user endpoints for Copilot usage billed directly to an individual account, including AI-credit usage.
- [GitHub usage-based billing for individuals](https://docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-individuals) confirms AI Credits as the current billing unit, while some annual plans may temporarily remain on legacy premium requests.
- [OpenAI: Using Codex with your ChatGPT plan](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan/) directs personal users to the Codex usage page or limit banner. Its documented analytics API is for eligible Enterprise workspaces, not a general personal quota API.
- [Anthropic: Using Claude Code with Pro or Max](https://support.anthropic.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan) states that Claude and Claude Code share plan limits and tells users to monitor allocation through Claude Code status.
- [Anthropic Claude Code CLI reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage) documents structured output for model queries, but does not document a noninteractive personal quota command. Do not use print mode for quota polling because it invokes the model.
- [CodexBar provider documentation](https://github.com/steipete/CodexBar/blob/main/docs/providers.md) and [CLI documentation](https://github.com/steipete/CodexBar/blob/main/docs/cli.md) are implementation evidence—not provider guarantees—that OAuth, web, local, and CLI strategies can retrieve normalized usage.

## Provider findings

### GitHub Copilot

GitHub is the strongest integration. Use the documented user billing endpoints and model the response as usage, not necessarily as a simple percentage remaining.

Before committing the UI contract, test the actual Copilot Student account because:

- the endpoint covers usage billed directly to the personal account;
- an educational entitlement may expose different billing or allowance fields;
- AI Credits and legacy premium requests can coexist during plan transitions;
- unlimited completions are a plan property, not a numeric remaining quota.

For the personal prototype, a fine-grained token is acceptable if the exact endpoint permission is confirmed from GitHub's live documentation. For distribution, prefer GitHub OAuth and request only the required read scope. Never claim that a guessed permission name is correct before the probe succeeds.

### OpenAI Codex

OpenAI exposes personal usage through its own product surfaces, but the reviewed public documentation does not provide a general personal quota REST API.

Probe in this order:

1. A supported structured Codex CLI or app-server method, if the installed version documents one.
2. Provider-owned status output that can be read without submitting a model turn.
3. A local cached quota snapshot whose timestamp and provenance can be shown.
4. An opt-in authenticated dashboard adapter, labeled experimental.
5. Local history, labeled local observation rather than quota.

Do not assume commands such as `codex status --json` exist. Do not parse interactive terminal output in the background until a probe proves that it is side-effect-free and stable enough. Never copy or sync the contents of Codex credential files.

### Claude

Anthropic confirms that Claude and Claude Code share Pro/Max limits. This is why local Claude Code logs cannot determine account-wide remaining capacity: usage may also occur on the web, mobile, or another machine.

Probe in this order:

1. A documented, non-model provider-owned status mechanism available in the installed Claude Code version.
2. A local cached provider quota snapshot with freshness metadata.
3. An opt-in authenticated web adapter, labeled experimental.
4. Local JSONL/`ccusage` analytics, labeled local observation.

Do not use `claude -p` to request usage: Anthropic documents it as a model query, so it can consume plan or API usage. A PTY-driven slash/status command must be tested to prove that it is local, produces no model turn, and can be terminated safely.

## Authentication and security

Preferred order:

1. Official OAuth or device authorization intended for third-party applications.
2. Invoke a provider-owned CLI/status interface while the CLI manages its credentials.
3. Read a non-secret local cache with explicit user permission.
4. Opt-in authenticated web session for a personal experimental adapter.

The application must not collect provider passwords or MFA codes, upload credentials, copy raw credential files into its own database, or sync cookies/tokens through CloudKit or an App Group. Secrets owned by the app belong in Keychain. Browser sessions and undocumented endpoints require an explicit warning, easy revocation, and a kill switch.

Authenticating and reading metadata normally does not consume model usage. That statement is not absolute: automation can consume usage if a supposed status command becomes a normal prompt. Each adapter therefore needs a side-effect test and conservative polling.

## Product and platform constraints

- A menu-bar app, local database, notifications, launch at login, and deterministic analytics are standard macOS work and are feasible.
- WidgetKit extensions should read an App Group snapshot; they should not launch CLIs, access browser sessions, or own credentials.
- Watch complications require a watchOS app/WidgetKit extension and realistic timeline-refresh expectations. CloudKit is suitable for small sanitized snapshots, not continuous real-time quota monitoring.
- Developer ID signing and notarization are compatible with an outside-the-Store personal release. Mac App Store feasibility must be reassessed after the authentication approach is known; credential-file access, subprocess automation, browser-cookie access, and private endpoints may conflict with sandboxing, review expectations, or provider terms.
- A no-backend design is feasible for one user's Apple devices. Public OAuth may require registered client configuration, callback handling, and potentially a small backend depending on provider rules.

## Main risks and mitigations

| Risk | Impact | Mitigation / gate |
|---|---|---|
| Undocumented Codex or Claude endpoint changes | Quota bars stop refreshing | Adapter isolation, fixtures, last-known-good cache, source labels, feature flag |
| Provider terms disallow credential or session reuse | Integration cannot ship | Terms review before distribution; prefer provider-owned CLI invocation and official OAuth |
| Student entitlement is absent from GitHub billing response | No authoritative Copilot remainder | Test the real account before designing the final allowance UI |
| CLI status automation triggers a model turn | Unexpected quota or charges | Side-effect test; never use model-query/print modes for health checks |
| Local totals are mistaken for account quota | Misleading recommendations | Separate official quota from local activity; never synthesize a precise remainder from logs |
| Polling causes rate limits or account protection | Stale/broken integrations | Five-minute default, foreground refresh, exponential backoff, provider-specific minimums |
| App Store sandbox/review restrictions | Commercial roadmap blocked | Treat outside-Store release as the committed target; run a later dedicated review |
| Watch/widget refresh expectations are too aggressive | Stale UI | Snapshot-only extensions, freshness labels, conservative timelines |

## Recommended scope

### Phase 0: capability probe

Build a small read-only harness before the app UI. It must capture sanitized fixtures and answer:

- Does GitHub return useful Student-plan allowance data, and with what permission?
- Can Codex return quota without a model turn, in a stable machine-readable form?
- Can Claude return quota without a model turn, in a stable machine-readable form?
- Which reset timestamps and quota windows are actually present?
- Which local fields reliably expose tokens, models, projects, tools, skills, or subagents?
- What polling limits and failure modes are observed?

Exit with one of `supported`, `experimental`, `local-only`, or `unavailable` for every provider capability. Do not require all providers to pass.

### MVP

Ship a menu-bar app with:

- GitHub authoritative usage if the Student probe passes;
- local Claude and Codex analytics;
- any proven Codex/Claude quota adapters behind an Experimental label;
- source, freshness, and confidence on every displayed metric;
- manual refresh plus conservative scheduled refresh;
- threshold notifications only for authoritative or provider-reported values;
- diagnostics and JSON export.

Defer CloudKit, Watch, causal explanations, provider recommendations, and sophisticated forecasting until the collection layer has several weeks of reliable data.

## Go/no-go criteria

Proceed with the personal MVP if:

- at least one provider yields provider-reported quota or allowance data;
- Claude and Codex local histories yield useful analytics;
- no probe requires passwords, raw-cookie pasting, or model turns;
- every value can carry source and freshness metadata;
- adapter failures degrade to cached/local-only states without blocking the app.

Do not market an integration as supported until it uses a documented provider interface or has an explicit provider agreement. Do not pursue Mac App Store distribution until authentication, sandboxing, subprocess behavior, dependency licensing, and provider terms have each passed a separate review.

## Final verdict

**Go for a personal prototype and outside-the-Store MVP.** The central technical architecture is sound, GitHub has a documented path, and open-source precedent reduces discovery risk for Codex and Claude. Treat those two account-quota adapters as experiments, not contractual product capabilities. The first deliverable should be the capability probe; its results should determine the final MVP rather than the other way around.
