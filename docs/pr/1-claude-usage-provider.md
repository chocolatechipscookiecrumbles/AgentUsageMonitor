# PR 1 — Claude usage provider

**Branch:** `feature/claude-usage-provider` → `main` · **Merge first** (PRs 2 and 3 build on it)

## Summary

- Claude Code becomes a real, user-reachable usage provider instead of a static preview: live five-hour and weekly figures on its own Settings page, read through a four-tier source hierarchy.
- Automatic refreshes can no longer raise a Keychain prompt, and the app signs with a stable identity so an "Always Allow" grant survives rebuilds.
- The cache stops decaying: a degraded refresh can no longer overwrite a current reading with an older one.

## Problem and root cause

**Symptom 1 — Claude showed nothing.** `ClaudeCodePreviewSettingsView` was a static card; no usage was reachable by a user.
**Cause:** `ClaudeUsageMonitor` polled `ClaudeRateLimitSnapshotReader` directly every 30s and bypassed `ClaudeUsageCollector` entirely, so the OAuth tier never ran in the app and two parallel representations of the same data coexisted.

**Symptom 2 — the Keychain prompt returned after every "Always Allow".**
**Cause:** `Scripts/build-app.sh` signed ad-hoc. An ad-hoc signature has no certificate, so its designated requirement is pinned to the binary's cdhash, which changes on every build. Keychain ACL entries key off that requirement, so each rebuild presented as a different application.
**Evidence:** `codesign -dv` reported `Signature=adhoc`, `TeamIdentifier=not set`.

**Symptom 3 — the cache held day-old data.**
**Cause:** `ClaudeUsageCollector` wrote whatever the fallback produced regardless of age, and ranked tier 3 above tier 4 unconditionally.
**Evidence:** a cache written seconds earlier contained a 47-hour-old statusLine capture (`5h 5%`, no weekly), having clobbered a current OAuth read (`5h 44%`, `7d 28%`).

## Scope and non-goals

**Included:**
- Tier 1 OAuth via Claude Code's Keychain credential; `KeychainPromptPolicy`; composite credential resolution with a visible degrade.
- Tier 2 CLI `/usage` probe — **manual only**, behind consent.
- Tier 3/4 freshness correctness.
- `ClaudeAgentSettingsView` built on the shared `AgentQuotaSessionSection`; `ClaudeConnectionController` wired to real state.

**Not included:**
- Menu-bar Claude card (PR 3 plans it).
- Browser sign-in via `claude setup-token` — implemented and unit-tested but **wired to nothing and shelved as unverified**; it must not be presented as working.
- Self-run PKCE OAuth — deliberately dropped to avoid `client_id` impersonation.

## Design and ownership

`ClaudeUsageMonitor` is the single owner of the Claude read cycle, mirroring `QuotaMonitor` for Codex. It owns `ClaudeUsageCollector` and polls on a 12-minute network-appropriate cadence (the previous 30s file poll would now mean an API call every 30 seconds).

Flow: `ClaudeUsageMonitor` → `ClaudeUsageCollector` → tier 1 `ClaudeOAuthUsageSource` (credential from `ClaudeCompositeCredentialStore`) → tier 3 `ClaudeRateLimitSnapshotReader` → tier 4 `ClaudeUsageCache`. Tier 2 sits outside this chain and is only invoked from the UI.

**Recovery boundary:** every tier failure degrades to the next; exhausting all of them yields an explicit `.unavailable(reason:)` state, never a zeroed quota. `ClaudeRefreshReason` decides whether a Keychain read may prompt — only `.userInitiated` may.

## Privacy, compatibility, and migration

- No token is persisted outside the Keychain, logged, or placed in the cache. A test asserts the setup-token never appears in a thrown error's description; a manual check greps the cache files for `sk-ant-`.
- Background reads pass `kSecUseAuthenticationUIFail`, so a scheduled refresh is structurally unable to prompt.
- Reading Claude Code's credential remains an explicit, disclosed user action, not a default side effect.
- **Migration:** none. The `.cli` case added to `ClaudeUsageSource` is additive; existing cache files decode unchanged.

## Regression proof

`ClaudeUsageCacheFreshnessTests.testOlderSnapshotDoesNotOverwriteNewerOne` recreates the observed failure: save a current OAuth snapshot, then a 47-hour-old statusLine one. **Before:** the stale snapshot won and the cache reported `5%`. **After:** the fresh OAuth read is retained.

`ClaudeCollectorFreshnessTests.testStaleStatusLineLosesToFresherCache` covers the ordering half — a 47h capture no longer outranks a recent cached read — while `testFreshStatusLineStillWinsOverOlderCache` pins the normal case unchanged.

`ClaudeUsageMonitorTests.testStopCancelsPolling` caught a cancellation bug: `start()` queued a task whose first action was the launch refresh with no cancellation check, so `stop()` immediately after could not prevent that read.

## Verification

| Check | State | Result |
|---|---|---|
| `swift test` | Run | 168 passed, 0 failures (44 baseline → 168) |
| Debug app launch | Run | Launches, no crash |
| Tier 1 live read | Observed | `plan pro · 5h 44% · 7d 28% · delivery live/oauth · via claudeCodeCredentials` |
| Tier 3/4 degrade | Observed | Invalid token → `tier 1 unavailable: unauthorized`, delivery falls to `passiveSnapshot` |
| Cache holds no secrets | Run | `grep 'sk-ant-'` over Application Support JSON → no match |
| Signed `.app` build | Run | A Developer ID TeamIdentifier was present (value redacted for public source; previously `not set`) |
| **Signed-app visual acceptance** | **Not run** | Settings page never opened by a human |
| **Tier 2 against real CLI output** | **Not run** | Costs tokens; parser tested on synthetic fixtures only |

## Risks, rollback, and limitations

**Risk:** the tier-2 parser targets `/usage` panel wording that is not a documented contract. If it drifts, the probe reports "the CLI ran but its usage output could not be read" — it fails closed and never fabricates a figure.

**Rollback:** revert the branch. No schema or file-format migration to unwind; the cache regenerates on the next refresh.

**Known limitations / unrun checks:**
- No human click-through of the Settings UI — button states, disconnect, and failure copy are test-covered but visually unverified.
- Tier-2 output parsing unverified against a real run.
- Running `.build/debug/CodexUsageMonitor` directly still prompts on every rebuild; only the signed `.app` carries a stable identity.
- The live cache is already corrupted from before the fix and self-heals on the next successful OAuth read.

## Documentation and review focus

Plans: `2026-07-21-claude-oauth-web-login-provider.md`, `2026-07-21-claude-usage-provider-wiring.md`, and the spike-findings addendum. Operating doc: `docs/claude-usage-verification.md`. Gate updated: `2026-07-20-claude-code-capability-research.md`.

**Riskiest decision to review:** making tier 2 manual-and-consented rather than an automatic tier. Anthropic documents `/usage` as consuming tokens, so an automatic fallback would spend quota to measure quota precisely when OAuth is already failing. The alternative is an automatic tier with a recurring cost.
