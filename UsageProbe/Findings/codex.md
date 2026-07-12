# Codex Phase 0 finding

Verified 12 July 2026 against `codex-cli 0.144.1` authenticated with ChatGPT.

## Classification

| Capability | Status | Source |
|---|---|---|
| CLI installation/version | Local-only | `codex --version` |
| Authentication state | Local-only | `codex login status` |
| Account rate limits | Experimental | App-server `account/rateLimits/read` |
| Account token-usage summary | Experimental | App-server `account/usage/read` |
| Allowlisted local-state metadata | Local-only | `~/.codex` file metadata |

## Confirmed response fields

The account rate-limit response included:

- plan type;
- primary used percentage, window duration, and reset timestamp;
- secondary used percentage, window duration, and reset timestamp;
- credit availability and balance.

The account usage response included lifetime tokens, peak daily tokens, current and longest streaks, longest-running turn duration, and daily usage buckets. The current harness retains only the summary because daily history was not required for the first capability decision.

No model prompt was sent. The app-server session sent only `initialize`, `account/rateLimits/read`, and `account/usage/read`. Credential-file contents were not read.

## Reliability finding

The method is technically feasible but not stable enough to call supported. Three close read-only samples produced materially inconsistent rate-limit snapshots:

1. 48% primary / 52% secondary used.
2. 1% primary / 3% secondary used, with a different primary reset timestamp.
3. 53% primary / 52% secondary used.

The token-usage summary remained stable. The discrepancy may reflect transient account selection, cache initialization, reset-credit state, or an app-server alpha defect; the available evidence does not establish causation. A production collector should sample repeatedly, reject implausible regressions unless confirmed, identify the account/limit ID, and retain last-known-good snapshots.

## Operational findings

- `codex login status` writes its human-readable result to stderr while exiting zero.
- App-server reads are asynchronous. Closing stdin immediately after sending requests cancels pending reads; the client must keep stdin open until the matching response IDs arrive.
- The app-server schema marks these methods experimental.

## Decision

Proceed with the Codex adapter as an experimental integration. Before using it for notifications or recommendations, add a repeated-sampling study and an account/limit identity guard.

## Current compact reader — 12 July 2026

The probe now makes three separate read-only app-server samples, rejects the observed transient near-empty pattern, and labels a result confirmed only when clean samples agree on the quota lane, reset time, and near-identical usage.

Latest confirmed live read:

| Field | Value |
|---|---|
| Plan | Plus |
| Credit balance | 2110.4350875000 |
| Available reset credits | 2 |
| Five-hour window | 7% used / 93% remaining; resets 12 July 2026, 20:05 CST |
| Weekly window | 60% used / 40% remaining; resets 18 July 2026, 14:00 CST |

The reader remains experimental. It shows the latest non-transient value as unconfirmed if clean samples disagree.

## Phase 0 completion — 12 July 2026

The final probe adds the remaining collection safeguards:

- sends the full `initialize` → `initialized` → `account/read` → rate-limit → usage protocol sequence;
- selects `rateLimitsByLimitId.codex` when the provider supplies multiple lanes;
- derives a one-way account fingerprint from the provider-reported account email without persisting that email;
- accepts a live result only when clean samples agree on account, lane, window reset, and near-identical usage;
- stores the last confirmed non-secret snapshot at `~/.codex-usage-probe/last-known-good.json` with owner-only permissions;
- falls back to that local snapshot when later samples are transient or inconsistent.

The final live read was confirmed for account fingerprint `ebd5bc582834561a` and lane `codex`. The store directory has mode `0700`; its snapshot file has mode `0600`; inspection confirmed that it contains no raw email or token.
