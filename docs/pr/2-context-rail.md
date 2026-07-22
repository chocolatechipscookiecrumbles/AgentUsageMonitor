# PR 2 — Multi-provider context rail

**Branch:** `feature/context-rail` → `main` · **Merge after PR 1** (builds on it)

## Summary

- The Settings context rail shows one status block per active provider instead of one card describing the selected agent.
- Each block shows the numbers the rail is actually opened for: plan, five-hour, weekly, connected status, and last refresh — with the provider named beside its icon.
- Removes a false privacy claim from shipped UI.

## Problem and root cause

**Symptom 1 — the rail carried little useful information.** It showed a `Current` row restating the page you were already on, and a `Quota status` row reporting refresh *mode* rather than whether the provider was connected. Neither answers "how close am I to a limit."
**Cause:** the rail was written when Codex was the only provider, so it described the selection rather than comparing providers.

**Symptom 2 — the Claude rail card asserted this app "does not read its files, credentials, usage, or account data."**
**Cause:** that copy was written while Claude was a static preview and was never revisited when Claude went live in PR 1. It is a false statement about data handling, not merely stale wording.

## Scope and non-goals

**Included:**
- `ProviderContextSummary` plus pure Codex and Claude adapters.
- `ProviderContextCard`, and `AgentConnectionsContextView` as a `ForEach` over active providers.
- `RelativeTimeText`, extracted so both providers render "last refresh" identically.
- Deletion of the Claude preview card and its privacy copy.

**Not included:**
- GitHub Copilot block — its capability gate has not passed.
- Any refresh action in the rail; it stays read-only.
- Live-ticking relative times — computed at render, not on a timer.

## Design and ownership

`ProviderContextSummary` is the single provider-neutral value type the rail renders; the view has no per-provider branching and no formatting logic. Two static adapters build it — Codex from `AgentConnectionState` + `QuotaPresentation` + `lastConfirmedAt`, Claude from `ClaudeConnectionState` + `ClaudeUsageDisplayModel` (reused, not re-derived).

`SettingsPreviewView` owns assembly, reading published state already on `QuotaViewModel`. `ProviderContextSummary.activeProviders(claudeIsUsable:)` is the single place deciding which providers appear.

**Recovery boundary:** an absent value renders `Unavailable` and a disconnected provider reads `Disconnected`. No path produces `0%`.

## Privacy, compatibility, and migration

- Removes an inaccurate privacy assertion; adds none. The rail renders only already-sanitized presentation values and touches no credential.
- **Migration:** none. No stored state added or changed.

## Regression proof

`ProviderContextSummaryTests.testCodexDisconnectedNeverShowsZeroPercent` and `testClaudeUnavailableNeverShowsZeroPercent` assert explicitly that a missing window is the placeholder and `XCTAssertNotEqual(..., "0%")` — the rail is the easiest surface in the app to invent a quota, and this is the guard against it.

`testCodexWithoutAConfirmedRefreshShowsUnavailable` encodes the decision that only a *successful* timestamp counts: a provider whose refreshes are failing must not read as recently refreshed.

`testBothProvidersShareTheSameRelativeWording` pins Codex and Claude to identical output, so the two cannot drift once someone edits one.

## Verification

| Check | State | Result |
|---|---|---|
| `swift test` | Run | 178 passed, 0 failures |
| Debug app launch | Run | Launches, no crash |
| **Signed-app visual acceptance** | **Not run** | Rail never viewed rendered |
| **Two stacked cards at `contextRailWidth`** | **Not run** | Spacing/scroll behaviour unverified |

## Risks, rollback, and limitations

**Risk:** the rail now renders two cards where it rendered one, at a fixed width inside an existing `ScrollView`. Layout crowding is plausible and unverified.

**Rollback:** revert the branch; the previous single-card rail returns. No stored state to unwind.

**Known limitations / unrun checks:**
- Not viewed rendered — the main gap.
- Relative times do not tick; "8 minutes ago" is correct at render and then ages silently until the next redraw.

## Documentation and review focus

Plan: `docs/superpowers/plans/2026-07-22-multi-provider-context-rail.md`, whose Task 1 records the four settled decisions.

**Riskiest decision to review:** using the last *successful* timestamp rather than the last attempt. It is the honest choice, but it means a provider that has been failing for hours shows an old "last refresh" with a `Connected` status — the alternative wording would be more alarming but arguably clearer.
