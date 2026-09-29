# Claude Usage Credits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans`, `swiftui-pro`, and `writing-for-interfaces`.

**Goal:** Present Claude usage-credit spending, limits, and prepaid balance without conflating them.

**Architecture:** Preserve the existing OAuth `extra_usage` mapping and verify every monetary field’s semantics before expanding it. Financial observations keep their own source time; quota-only readings may retain them as Last known but cannot refresh them.

**Constraints:** No estimated costs, assumed currency, inferred prepaid balance, automatic top-up, purchase control, spend-limit mutation, browser scraping, or new credit alerts.

## Tasks

- [x] Audit the existing source evidence; populated credit units/reporting period remain unverified (see boundary below).
- [x] Stop formatting missing spend as zero; preserve explicit zero with a supplied currency and disabled states.
- [x] Add optional `extraUsageObservedAt` metadata to retain financial observation time across quota-only readings; older caches remain decodable.
- [x] Separate `Usage-credit spending` from `Monthly spending limit`; show `Credit balance: Unavailable`. Do not calculate remaining allowance.
- [x] Show unsupported values as Unavailable with the shared `Open Claude Usage` action.
- [x] Run narrow regressions: 35 display, collector-freshness, cache, and snapshot tests passed after integration, exit 0.
- [x] Complete signed-app acceptance; no genuine balance or unlimited-limit fixture is supported by inspected evidence.

## Source evidence and boundary — 2026-09-22

The sole captured OAuth fixture reports `extra_usage.is_enabled = false` with
null `used_credits`, `monthly_limit`, and `currency`. Existing non-null display
tests are synthetic; they verify formatting, not provider units. Neither the
status-line bridge nor `/usage` parser supplies financial values or balance.

[Anthropic's credit guidance](https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans)
distinguishes month-to-date spending, monthly caps, and prepaid funds, but does
not define the OAuth numeric representation. The existing direct numeric mapping
is retained; no conversion or new balance field is guessed. Missing, nonfinite,
negative, or missing/unrecognized-currency amounts display Unavailable; a missing
cap is not labeled unlimited.

`extraUsageObservedAt` records the financial observation separately when passive
quota replaces an OAuth snapshot. Legacy financial snapshots use their original
`capturedAt`. The collector reads only its local cache on the passive path, and
the cache preserves the financial time on subsequent writes. Settings labels the
financial timestamp separately from quota freshness.

Review follow-up: an OAuth response containing only `extra_usage` now updates
the financial observation while retaining any cached quota with its original
capture time and cached delivery. Without cached quota, the financial-only
snapshot is saved for a later passive capture; no quota window is invented.
Financial-only cache timestamps cannot block an otherwise usable passive quota
from being saved. A truly empty OAuth response still cannot replace good cache.
The OAuth source uses its injected clock for its actual observation timestamp.

Follow-up verification passed 61 focused tests (exit 0), including financial-only
responses with and without prior quota, later passive retention, independent
financial timestamp display, an actual legacy JSON cache lacking the new field,
and the existing empty-response/cache-freshness regressions. The financial-only
regression failed before the fix; a newer-financial/older-passive cache-order
case also failed before correcting the quota-only timestamp comparison.
Command: `CLANG_MODULE_CACHE_PATH=/tmp/claude-financial-module-cache swift test --disable-sandbox --filter 'ClaudeUsageDisplayModelTests|ClaudeCollectorFreshnessTests|ClaudeUsageCollectorTests|ClaudeUsageCacheTests|ClaudeUsageCacheFreshnessTests|ClaudeUsageSnapshotTests|ClaudeOAuthUsageSourceTests'`.
The run reports the existing deprecated `SecKeychainGetUserInteractionAllowed`
and `SecKeychainSetUserInteractionAllowed` warnings in addition to SwiftPM's
inaccessible user-cache warnings. `git diff --check` passes.

Final cache follow-up — 2026-09-23: financial-only cached observations now survive
later OAuth failure and remain available through the monitor for Settings while
quota windows remain nil. Cache writes select quota by its capture time and
financial data by `extraUsageObservedAt` independently; an older quota snapshot
can contribute newer financial data without replacing fresher quota. The
existing collector regression now performs success, failed refresh, and a
passive capture 30 seconds older than the financial observation, then asserts
both persisted timestamps. One cache regression checks independent merging in
both directions; one monitor regression protects actual financial visibility.
All three failure boundaries were reproduced before correction.

Final focused command added `ClaudeUsageMonitorTests` to the prior filter and
passed 75 tests with zero failures, exit 0. Evidence:
`/tmp/claude-financial-fallback-tests.log`. Existing Keychain deprecation and
SwiftPM cache-access warnings remain; `git diff --check` passed. Signed visual
acceptance is owned by the parent workstream.

Two deterministic regressions reproduced the prior defects before the fix:
missing amount/currency generated invented money, and passive capture discarded
the last financial data (four failed assertions across two tests). The integrated
rerun passed 35 tests with zero failures using `CLANG_MODULE_CACHE_PATH=/tmp/claude-financial-module-cache swift test --disable-sandbox --filter 'ClaudeUsageDisplayModelTests|ClaudeCollectorFreshnessTests|ClaudeUsageCacheTests|ClaudeUsageSnapshotTests'`.
The timestamp regression also confirms no credential read occurs during passive
refresh. SwiftPM reported inaccessible user cache directories and a read-only
manifest-cache database; no compiler error remained in the successful run.
Signed-app visual acceptance remains pending. Existing
currency formatting does not establish provider units; populated amounts require
a separately verified response before claiming full financial-source validation.

## Acceptance

Every displayed monetary value has a verified meaning and timestamp. Unsupported prepaid balance is explicitly unavailable rather than estimated.

Signed-app acceptance on 2026-09-23 confirmed spending, balance, limit, and
financial timestamp rows at the default size in Light/Dark and with the Context
Rail hidden/visible. An explicit `/usage` run exposed that manual publication
discarded the retained financial observation; `applyManualSnapshot` now merges
the prior observation, protected by a focused regression.
