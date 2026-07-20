# GitHub Copilot Personal-Usage Capability Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine whether the user's Copilot entitlement exposes an official, privacy-safe personal usage or allowance signal that could justify a future provider adapter, without changing the app or rendering speculative Agents UI.

**Architecture:** This is one user-authorized, read-only probe—not an app feature. A short-lived fine-grained GitHub token with only **Plan: read** calls two documented user billing endpoints through GitHub CLI. Raw responses remain in a private temporary directory; the repository records only a sanitized outcome. Current community projects also use GitHub's undocumented `copilot_internal/user` implementation endpoint. CodexBar's current reference implementation obtains an OAuth token through a user-initiated device flow, then sends that token to the internal endpoint. That is an experimental research lead only: it must not be adopted or tested without a separate explicit privacy, compatibility, and authentication decision. The existing Agents selector remains deferred until a later adapter actually declares support.

**Tech Stack:** GitHub CLI (`gh`), GitHub REST API version `2026-03-10`, `jq`, macOS shell, planning documentation.

## Global constraints

- This plan is explicit read-only research. It does not authorize a Copilot adapter, Settings UI change, credential persistence, background polling, or an Agents selector implementation.
- Use a fine-grained personal access token with only **Plan: read**. Do not use a password, browser cookie, SSH key, classic broad-scope token, organization token, or a token copied into the repository.
- Never print a token, put it in shell history, environment files, source control, diagnostics, screenshots, or a PR body. Keep raw JSON only in a mode-`700` `mktemp -d` directory, then remove it.
- Call only `GET /users/{username}/settings/billing/ai_credit/usage` and `GET /users/{username}/settings/billing/premium_request/usage`. Do not query organization, enterprise, Copilot-chat, or model endpoints.
- The endpoints report billed usage. Do not infer a remaining Copilot allowance, reset time, connection state, or authentication state from price, quantity, reporting period, or an empty array.
- A `403`, `404`, empty response, or unpresentable contract is a valid outcome. Do not broaden permissions or try unofficial web/session/CLI scraping.
- Treat `GET /copilot_internal/user` and `/copilot_internal/v2/token` as undocumented implementation endpoints even though GitHub lists the path family in its firewall allowlist. GitHub's public REST reference supplies no versioned schema, permission contract, rate-limit guidance, or stability commitment for personal quota retrieval through those paths.
- Do not read `~/.config/github-copilot/apps.json`, OpenCode authentication files, IDE secret stores, browser cookies, or another application's OAuth tokens. Do not persist or display a Copilot OAuth access token. Do not reuse the VS Code OAuth client ID or any other application's OAuth registration. A future manual probe is permitted only after explicit user approval of an authentication design that avoids those sources and uses this product's own registered OAuth client.
- Browser-budget scraping is out of scope. It requires browser cookies and anti-forgery request state, has no public personal REST contract, and must not become a fallback when the experimental quota request fails.
- Make no app-source or general-test changes. A later reproducible adapter defect may earn one narrow deterministic regression test.
- Do not change the global Settings sidebar, `AgentsSettingsView`, `AgentProvider`, `QuotaMonitor`, refresh cadence, notifications, or native menu. [Agent Selector Task 6](2026-07-14-settings-provider-followups.md#task-6-replace-the-agents-title-with-a-supported-agent-selector) remains separately gated on a real adapter.
- The user manually creates any GitHub PR.

## Source facts and decision rule

- GitHub documents personal billing endpoints for Copilot usage billed directly to a user; organization- or enterprise-billed usage is excluded. User endpoints accept a fine-grained token with **Plan: read** and cover at most 24 months of history.
- AI-credit and premium-request responses document period and usage items, not a user's included allowance, remaining allocation, reset schedule, or app session state.
- A 2026 project audit found current scripts and applications calling the undocumented `api.github.com/copilot_internal/user` endpoint. Their observed payloads include `quota_snapshots` with `entitlement`, `remaining`, and reset fields, but their implementations obtain tokens from GitHub Copilot/OpenCode local authentication files, perform an internal token exchange, or require IDE-emulation headers. This evidence proves an experimental implementation path, not a supported product interface.
- CodexBar's `copilot.md` documents a more bounded variant: an explicit GitHub OAuth device flow with `read:user`, followed by `copilot_internal/user`. It maps `premiumInteractions` first, then `chat`, and derives its plan label from `copilotPlan`. Its source nevertheless uses the VS Code client ID, persists the OAuth token in its own configuration, and sends VS Code/Copilot identifying headers. Its optional budget feature also imports browser cookies. None of those implementation choices is approved for this app.
- `AgentProvider` presently includes `codex`, `claudeCode`, and `githubCopilot`, but only Codex has an adapter. Enum membership is not support evidence.
- The supplied Agents Selector image is a structural reference for a horizontal, scrollable, non-color-only selection row. It does not approve the illustrated provider list, icons, colors, or metrics for production.

| Probe result | Meaning | Next action |
| --- | --- | --- |
| **usage-only** | At least one documented endpoint returns `200`, but no official included limit, remaining amount, or reset semantics are present. | Record personal billed-usage evidence. Do not add a quota adapter or enable Copilot in the selector. |
| **allowance-capable** | An authorized documented response supplies an explicit allowance or remaining amount with clear period/reset semantics, and the user approves its presentation. | Write a separate `feature/copilot-provider` plan covering adapter, connection, cache/freshness, errors, cadence, privacy, and signed Settings acceptance. |
| **experimental-internal** | An explicit future decision accepts the undocumented internal route and a user-mediated authentication design can obtain a disposable token without reading credential files, cookies, or another app's secret store. | Write a dedicated ADR and experimental-prototype plan. It must use no automatic polling, use a user-triggered request only, clearly label the source Experimental, preserve no token, and define immediate removal on schema/auth failure. It does not authorize a shipped provider or selector entry. |
| **unavailable** | The response is `403`, `404`, `400`, `5xx`, has no personally billed Copilot data, or cannot be presented truthfully. | Record only the category, revoke the token, keep Copilot planned, and do not try undocumented sources. |

## File structure

| File | Responsibility |
| --- | --- |
| Create `docs/superpowers/plans/2026-07-19-github-copilot-capability-probe.md` | Scope, commands, outcome taxonomy, and adapter gate. |
| Modify `docs/product/planning-board.md` | Queue only this read-only probe; retain the selector gate. |
| Modify `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md` | Permit this explicit research exception without advancing a provider feature. |

---

### Task 1: Create a one-use probe credential

**Files:**
- Modify: this plan after the probe.
- Do not modify application source.

**Interfaces:**
- Consumes: a user-created fine-grained token for the personal account under test.
- Produces: an in-memory token and private temporary directory only.

- [x] **Step 1: Create the token manually.**

In GitHub's fine-grained-token UI, select the personal account being tested and grant exactly **Plan: Read-only** under user-account permissions. Use a short expiry and label it `codex-usage-monitor-copilot-probe`. Do not send the token to an agent.

- [x] **Step 2: Hold the token only in the current terminal session.**

```zsh
read -rs copilot_probe_token
printf '\n'
copilot_probe_dir="$(mktemp -d)"
chmod 700 "$copilot_probe_dir"
```

Expected: the token is not echoed and the temporary directory is private.

- [x] **Step 3: Confirm the account without revealing the token.**

```zsh
github_login="$(GH_TOKEN="$copilot_probe_token" gh api user --jq .login)"
printf 'Authenticated GitHub account: %s\n' "$github_login"
```

Expected: one login is printed. If this fails, record `unavailable — authentication`, clean up in Task 3, and stop.

### Task 2: Call the documented reports and inspect only schema

**Files:**
- No repository changes.

**Interfaces:**
- Consumes: `copilot_probe_token`, `copilot_probe_dir`, and `github_login`.
- Produces: temporary JSON or endpoint-status categories and field names only.

- [x] **Step 1: Request AI-credit billed usage.**

```zsh
GH_TOKEN="$copilot_probe_token" gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "/users/$github_login/settings/billing/ai_credit/usage" \
  > "$copilot_probe_dir/ai-credit.json"
ai_credit_status=$?
printf 'AI-credit endpoint exit status: %s\n' "$ai_credit_status"
```

Expected: `0` writes JSON only in the temporary directory. A nonzero exit is an `unavailable` candidate; preserve only its HTTP category.

- [x] **Step 2: Request premium-request billed usage.**

```zsh
GH_TOKEN="$copilot_probe_token" gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "/users/$github_login/settings/billing/premium_request/usage" \
  > "$copilot_probe_dir/premium-request.json"
premium_request_status=$?
printf 'Premium-request endpoint exit status: %s\n' "$premium_request_status"
```

Expected: `0` writes JSON only in the temporary directory. `403` and `404` are valid evidence.

- [x] **Step 3: Print field paths, never values.**

Run the appropriate command only for each successful endpoint:

```zsh
jq -r 'paths(scalars) | map(if type == "number" then "[]" else tostring end) | join(".")' \
  "$copilot_probe_dir/ai-credit.json" | sort -u

jq -r 'paths(scalars) | map(if type == "number" then "[]" else tostring end) | join(".")' \
  "$copilot_probe_dir/premium-request.json" | sort -u
```

Expected: field-name paths such as `timePeriod.year` and `usageItems.[].unitType`, without response values. `grossQuantity`, prices, amounts, counts, and a period alone are not an allowance contract.

- [x] **Step 4: Classify the outcome.**

Use the table above. Do not derive a quota from billed consumption or retry with a broader token.

### Task 3: Destroy private artifacts and record the decision

**Files:**
- Modify: `docs/superpowers/plans/2026-07-19-github-copilot-capability-probe.md`
- Modify: `docs/product/planning-board.md`
- Modify: `docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md` only if the outcome changes sequencing.

**Interfaces:**
- Consumes: HTTP categories, field names, and one taxonomy outcome.
- Produces: sanitized durable evidence and an unambiguous provider/selector decision.

- [ ] **Step 1: Remove the token and raw temporary JSON.**

```zsh
unset copilot_probe_token github_login ai_credit_status premium_request_status
rm -rf "$copilot_probe_dir"
unset copilot_probe_dir
```

Expected: neither token nor raw JSON remains in the session or filesystem.

- [x] **Step 2: Append only sanitized evidence.**

```markdown
### Probe evidence — YYYY-MM-DD

- Credential: fine-grained personal token, `Plan: read`, short-lived; revoked after probe.
- AI-credit endpoint: [200 / 403 / 404 / other category]; field names observed: [names only].
- Premium-request endpoint: [200 / 403 / 404 / other category]; field names observed: [names only].
- Result: **[usage-only / allowance-capable / unavailable]**.
- Decision: [keep Copilot planned / prepare a separate adapter plan]. No raw response, handle, token, monetary amount, usage count, or billing history was retained.
```

- [x] **Step 3: Synchronize planning status.**

For `usage-only` or `unavailable`, set the Copilot board row back to **Deferred** and say that no verified remaining-allowance contract exists. For `allowance-capable`, keep it **Queued** with a next action to write a separate provider-adapter plan. In all outcomes, keep the supported-agent-selector row deferred until that adapter exists.

### Probe evidence — 2026-07-19

- Credential: a user-created fine-grained personal token was used in a private terminal session. The temporary directory was reported mode `700` and the exact raw-response directory was removed after inspection; token revocation and unsetting it from the originating terminal remain user actions to complete.
- Authentication: a GitHub user endpoint authenticated successfully. The account identifier is intentionally not recorded.
- AI-credit endpoint: command exit `0`, HTTP `200`; scalar field paths reported: none.
- Premium-request endpoint: command exit `0`, HTTP `200`; scalar field paths reported: none.
- Result: **unavailable** — the observed responses supplied no reported scalar personally billed-usage fields and no explicit allowance, remaining amount, or reset contract.
- Decision: keep GitHub Copilot planned. Do not build a provider adapter, quota display, refresh loop, or Agents-selector entry from these responses. No raw response, account identifier, token, monetary amount, usage count, or billing history is retained in this repository.

### Research correction — 2026-07-19

- The documented personal billing endpoints remain insufficient: GitHub's own current UI can show included-credit consumption, while those REST reports are billed-usage reports and did not yield a presentable allowance contract in this probe.
- Current community projects can instead query `api.github.com/copilot_internal/user`; their source parses entitlement, remaining, and reset fields from internal quota snapshots. GitHub publicly lists the path family as Copilot user-management traffic for firewall allowlists, but does not document it as a public quota API.
- The discovered projects obtain an OAuth token from local Copilot/OpenCode state or use an internal token exchange and IDE-identifying headers. That violates this repository's no-credential-file/no-token-persistence boundary. The route is therefore recorded as **experimental-internal**, not adopted, and must not be used without a separate explicit decision.

### CodexBar reference assessment — 2026-07-19

CodexBar is the most complete current implementation examined. Its documented sequence is:

1. The user begins a GitHub OAuth device flow with `read:user`.
2. Its app receives an OAuth access token after the user completes GitHub's browser confirmation.
3. It queries the undocumented `GET /copilot_internal/user` endpoint using that token and Copilot/VS Code-identifying headers.
4. It reads `premiumInteractions` as the primary window, `chat` as a secondary window, `copilotPlan` as the plan label, and a quota reset field when present.

That proves a practical experimental path, but it cannot be copied wholesale:

| CodexBar element | Assessment for Codex Usage Monitor |
| --- | --- |
| User-initiated GitHub device flow | **Candidate only.** GitHub officially documents device flow, but this app must register and use its own OAuth client, obtain an explicit product/authentication decision, and explain that the later quota request is undocumented. |
| VS Code OAuth client ID | **Rejected.** It is another application's registration and must not be shipped or impersonated. |
| `copilot_internal/user` with editor/plugin headers | **Experimental only.** The response is useful but lacks a public schema, permission, rate-limit, and compatibility commitment. A change or `401`/`403` must disable the experiment rather than fall back to scraping. |
| Persisting the OAuth token in an app config | **Rejected under current policy.** An ongoing monitor would require a new, explicit decision about secure storage, retention, revocation, and account switching; the current experiment may retain a token only in process memory for the user-triggered request. |
| Optional billing-budget fetch using browser cookies and nonce | **Rejected.** It reads browser session material and is web scraping, not a provider adapter fallback. |
| Local Copilot usage/cache discovery | **Not found.** The examined CodexBar Copilot path uses GitHub OAuth plus a network request, not a local Copilot cache as its quota source. |

#### Required ADR decision before any experimental prototype

- Register a product-owned GitHub OAuth app with device flow enabled. Do not use CodexBar's or VS Code's client ID.
- Limit the first prototype to one explicit **Check experimental Copilot quota** action. Hold its OAuth token only in memory for that request, do not automatically refresh, do not add it to diagnostics, and discard raw payload bytes after typed decoding.
- Display only an Experimental result whose fields were present and semantically valid: plan label, available percentage/amount, and reset time only when the response supplies it. Do not synthesize a reset date or report an entitlement as a guaranteed plan allowance.
- Treat authorization failure, a changed schema, missing expected fields, enterprise-only behavior, or provider incompatibility as a disabled experimental result with recovery guidance—not as permission to read cookies, local credentials, or a different application's secrets.
- Define the user's revocation route before shipping any authentication UI. The prototype does not authorize durable refresh, notifications, the Agents selector, Keychain persistence, or a Copilot provider release.

- [ ] **Step 4: Run documentation checks.**

```zsh
git diff --check
rg -n "copilot_probe_token|GH_TOKEN=|api.github.com/users" docs/superpowers/plans docs/product || true
```

Expected: no whitespace errors; any match is a literal safe command example, never a token value or response data.

- [ ] **Step 5: Commit sanitized documentation only.**

```zsh
git add docs/superpowers/plans/2026-07-19-github-copilot-capability-probe.md \
  docs/product/planning-board.md \
  docs/superpowers/plans/2026-07-13-codex-daily-driver-roadmap.md
git commit -m "Plan GitHub Copilot capability probe"
```

Expected: no raw response or temporary file is in the commit. Before a push, generate a filled manual PR draft; never create a GitHub PR.

## Acceptance criteria

- Only a short-lived `Plan: read` fine-grained token and the two documented personal endpoints are used.
- Raw account data, values, token, and handle never enter the repository or an agent transcript.
- The result is one of `usage-only`, `allowance-capable`, or `unavailable`, with dated field-name-only evidence.
- No quota percentage, reset time, refresh, notification, connection, or agent-selection behavior is created from incomplete billing data.
- The horizontal Agents selector stays deferred until a separately planned and implemented adapter is real; the reference image does not add placeholder providers.
