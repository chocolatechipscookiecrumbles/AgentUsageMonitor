# Model Adaptation Implementation Plan

> **For agentic workers:** Use `executing-plans` to implement remaining tasks, with `systematic-debugging` and `test-master` for demonstrated defects.

**Goal:** Accept new provider model identifiers without a per-model app release, while preserving honest attribution when the provider supplies no model.

**Architecture:** Keep provider records and `LocalActivityRequest.modelID` authoritative. Reuse `LocalActivityModelName` for presentation and the existing activity sources, reconciliation, cache, and aggregation. Model identity, friendly labels, capabilities, and pricing are separate concerns.

**Tech Stack:** Swift, Foundation, existing JSONL readers and XCTest.

## Constraints

- No model allowlist for ingestion, no remote executable rules, no new dependency or polling owner.
- New names must not suppress token evidence or invent prices/capabilities.
- Preserve provider-native token arithmetic, request identity, privacy gates, cache compatibility, top-three/Other treatment, and menu geometry.
- A new name in an existing schema can work automatically. A changed schema or token meaning may still require an app update; do not promise arbitrary future schema compatibility.
- Astra and Claude Fable 5 and 5.1 remain the requested product names. Only observed identifiers establish mappings.

## Diagnosis — 2026-09-23

A read-only scan of September 22–23 Codex session records emitted only model identifiers and aggregate token-event counts: `gpt-5.6-sol` 387, `gpt-6-astra` 136, `codex-auto-review` 48, absent identifier 1. These are raw token-event counts, not reconciled request or billing counts. No transcript content or credentials were printed.

`CodexLocalActivitySource` retains arbitrary strings from model/model_name and turn context. `LocalActivityRequest` and the cache preserve them. The defect is downstream: `LocalActivityModelName.shortName(for:)` recognizes GPT/Sonnet/Opus/Haiku version patterns, then returns Unknown model for every other supplied string. Both Model usage aggregation and Last request use it.

Thus `codex-auto-review` was mislabeled. `gpt-6-astra` already renders GPT-6: the lost Astra suffix is existing family grouping, not missing ingestion. One event genuinely lacks model evidence and must remain Unknown model. This establishes a concrete cause in recent records; it does not prove every historical unknown has the same cause.

## Task 1 — Fix the demonstrated unknown-name defect

**Files:** `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityModels.swift`; `CodexUsageMonitor/Tests/CodexUsageMonitorTests/LocalActivityReconciliationRegressionTests.swift`.

**Interface:** Keep `LocalActivityModelName.shortName(for: String?) -> String` unchanged.

- [x] Add one deterministic regression: `codex-auto-review` and a synthetic unseen family retain their names; nil/blank remain Unknown model; Astra preserves the current GPT-6 abbreviation.
- [x] Observe the regression fail before production edits: two assertions returned Unknown model.
- [x] Trim surrounding whitespace; retain existing recognized abbreviations; return the supplied identifier when no abbreviation applies.
- [x] Complete main-scheme build, narrow tests, and signed build; all exited 0.
- [ ] Signed-app model-row visual acceptance remains pending: UI automation timed out during the normal quit/relaunch sequence. Do not infer acceptance from a successful build or the prior process's Settings window.

This implements the minimum automatic support already needed. It does not require a model catalog download or cache migration: stored requests retain raw identifiers and are reaggregated.

## Task 2 — Keep identity independent of friendly grouping (draft)

**Files:** `Activity/LocalActivityModels.swift`, `Menu/ProviderTokenActivityPresentation.swift`, `Menu/ProviderTokenActivityCard.swift`, all under `CodexUsageMonitor/Sources/CodexUsageMonitor/`; existing activity regression tests.

**Interface:** Retain `LocalActivityRequest.modelID` and `LocalActivityModelShare.sourceModelIDs`. Do not use a display label as evidence of model capabilities.

- [x] Make an explicit product decision about family versus variant grouping. **Decided 2026-09-30 (user): always show the variant.** `LocalActivityModelName` keeps the alphabetic words after the version (`gpt-6-astra` → GPT-6 Astra, `gpt-5.6-sol` → GPT-5.6 Sol, `gpt-4o-mini` → GPT-4o Mini) and drops dates and context tags (`-20250929`, `[1m]`), so variants keep separate rows. `fable` joins the Claude families from Anthropic's published `claude-fable-5-1` identifier.
- [x] For unfamiliar families, use their supplied identifier as the group label. Do not strip suffixes/dates generically: a suffix can distinguish variants.
- [ ] Bound visible text in the existing single-line row and expose the full value through accessibility/help; sanitize control characters at the display boundary without changing stored identity.
- [x] (Already true: the model row's VoiceOver value lists the sorted source identifiers; the visible name is `lineLimit(1)`.) Preserve `sourceModelIDs` through `ProviderTokenActivityPresentation.ModelRow`; use the sorted identifiers to construct help text. Avoid a global model registry merely for labeling.
- [ ] Inspect known, unknown-family, missing, long, and Unicode identifiers at 340-point menu width with keyboard/VoiceOver and Light/Dark. No host or row-count changes.

## Task 3 — Evolve parsers only from verified evidence (draft)

**Files:** `Activity/CodexLocalActivitySource.swift`, `Activity/ClaudeLocalActivitySource.swift`, `Activity/LocalActivityCache.swift`, existing `LocalActivityReconciliationRegressionTests.swift`.

- [ ] Keep Codable model fields as strings, not enums. Ignore unrelated additive fields; keep validation of token values and request identity strict.
- [ ] When a missing-model report recurs, capture only the relevant event type, key paths, provider/version, and model fields in a sanitized fixture. Never recursively search arbitrary transcript text for a model-like string.
- [ ] Replay the fixture through the real source scanner. Only add an alias/path if the provider record verifies its meaning.
- [ ] Review attribution precedence using a real contradictory fixture before changing it: current Codex order is latched turn context, event model, then token-info model. Do not relabel historical requests from the current selected model.
- [ ] If verified parser semantics change, invalidate affected in-memory parse results and reparse source records. Keep request deduplication intact; do not infer missing models using another session or global settings.
- [ ] Record malformed/missing/unrecognized as distinct diagnostic conditions using existing diagnostics only when needed; never create recurring user alerts for a new name.

## Task 4 — Optional provider labels, only when needed (draft)

- [ ] Prefer a display label supplied by the same provider event if future evidence proves one exists. Cache it as optional metadata with raw ID remaining authoritative; old caches must decode.
- [ ] Do not fetch a catalog merely to show activity. The raw-ID fallback already handles unseen names offline. Add catalog integration only if a separate requirement needs verified friendly names/capabilities, using an official permitted interface and retaining offline fallback.
- [ ] Keep prices unavailable without a verified pricing source; neither model version nor token counts establishes account spend.

## Verification and handoff

Run from `CodexUsageMonitor`: `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' build`, then `swift test --disable-sandbox --filter 'LocalActivity|ProviderTokenActivity'`, then `./Scripts/build-app.sh`. Expected exit 0 for each; report warnings rather than altering signing/build settings.

Update `UsageProbe/README.md`, `docs/development/operating-notes.md`, `CONTEXT.md`, and the planning board. Keep this change distinct from the already uncommitted Claude work; no commit or push is part of this request.

### Actual verification — September 23

- Red: `swift test --disable-sandbox --package-path CodexUsageMonitor --filter LocalActivityReconciliationRegressionTests/testSuppliedUnrecognizedModelIsNotReportedAsMissing` failed with the two expected Unknown model mismatches.
- Main `xcodebuild` with derived data under `/tmp/agent-monitor-model-derived`: exit 0, BUILD SUCCEEDED.
- `swift test --disable-sandbox --package-path CodexUsageMonitor --filter 'LocalActivity|ProviderTokenActivity'`: exit 0, 16 tests, zero failures; includes the regression now passing.
- `CodexUsageMonitor/Scripts/build-app.sh`: exit 0, Developer ID Application signature.
- Compiler warnings remain the legacy `SecKeychainGetUserInteractionAllowed`, `SecKeychainSetUserInteractionAllowed`, and `SecKeychainCopyDefault` deprecations; asset processing emits existing CoreMedia/MediaToolbox dyld diagnostics. No build settings changed.
- `git diff --check`: exit 0. No production usage/cache/notification fixtures injected.
- UI automation resolved the checkout app and read its existing Settings, but normal quit/relaunch timed out. No final model-row, Light/Dark, or VoiceOver acceptance claimed for this fix. Stop the automation rather than attaching a debugger or forcibly killing a process.

## Verification log — variant names (2026-09-30)

- Red first: with the updated expectations, `LocalActivityReconciliationRegressionTests` failed 4 assertions (`gpt-5.6-sol` → GPT-5.6, `gpt-5.1-codex-max` → GPT-5.1, `gpt-4o-mini` → GPT-4, `gpt-6-astra` → GPT-6); the Claude date and context-tag cases already passed. Green after the change. The Fable assertion failed (`claude-fable-5-1` returned raw) before adding the family, then passed.
- `swift test`: 318 tests, 1 skipped, 0 failures.
- Not yet observed: the signed-app model rows at 340 points with long variant names, VoiceOver, and Light/Dark. Planned on the 0.1.0 release-candidate build.
