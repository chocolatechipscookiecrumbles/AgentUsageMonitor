# Codex Local Activity Recovery Diagnosis Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `systematic-debugging` and `diagnosing-bugs` throughout. Use `test-master` only after the released failure is reproduced. Do not implement a speculative parser fix. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the 0.0.1 Codex Token Monitor failure, identify the exact discovery/read/decode/reconciliation boundary, and protect the smallest evidence-backed fix.

**Architecture:** `LocalActivityMonitor` remains the sole scheduler/publisher and `CodexLocalActivitySource` remains the actor that owns decoded per-file state. Diagnosis adds a sanitized stage summary at their boundary rather than logging paths or raw records. Production behavior changes only after a fixture that fails on the old code and passes on the proposed fix exists.

**Tech Stack:** Swift 6.2, Foundation, Darwin descriptor-relative traversal, CryptoKit hashing, XCTest, signed `.app` inspection. No network call and no model turn.

## Global Constraints

- Do not ask for, copy, log, export, or commit raw Codex JSONL records, prompts, responses, paths, session IDs, turn IDs, provider event IDs, or record contents.
- Diagnostic output may contain only provider, resolved-root kind (`default`, `explicit`, `missing`, `unreadable`), file/line counts, stable stage enum, stable failure category, and aggregate presence booleans. No token value is needed to locate the failure.
- A valid empty day is `.available` with zero in-range requests. Missing roots, unreadable/unsafe roots, zero decodable usage claims, and reconciliation failure remain distinct.
- `CODEX_HOME` is part of discovery. The current local-activity convenience initializer ignores it even though connection/login honors it; fix that reproducible discovery defect independently, but do not claim it explains the reported default-home failure.
- Preserve descriptor-relative `O_NOFOLLOW` traversal, field-scoped decoding, opaque identities, bounded app-owned cache, actor isolation, cancellation/generation guards, and cache purge on collection disable.
- One malformed usage claim may make a source unavailable if trustworthy reconciliation is impossible. An unrelated unknown record type or harmless new field must not fail the whole root. The diagnostic must establish which case occurred before changing strictness.
- Add automated coverage only for reproduced failures. Do not add broad parser schema or happy-path tests.
- Enrollment from the first-launch plan gates whether a production scan starts. The standalone diagnostic may run only from an explicit command-line flag.

## File Structure

### Create

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/CodexActivityRootResolver.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityDiagnosticSummary.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityDiagnosticCommand.swift`
- `docs/development/codex-local-activity-diagnostic-results.md`

### Modify only as evidence requires

- `CodexUsageMonitor/Sources/CodexUsageMonitor/CodexUsageMonitorApp.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityMonitor.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/CodexLocalActivitySource.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityJSONLReader.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityFileObserver.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Activity/LocalActivityCache.swift`
- The narrowest existing `LocalActivity*RegressionTests.swift` file matching the reproduced boundary.
- `UsageProbe/README.md`, `docs/development/operating-notes.md`, `docs/product/follow-ups.md`, and `docs/product/planning-board.md`.

## Diagnostic Interfaces

```swift
enum CodexActivityRootKind: String, Codable, Sendable {
    case defaultHome
    case explicitCodexHome
}

struct CodexActivityRootResolver: Sendable {
    func sessionsRoot(environment: [String: String], homeDirectory: URL) -> (URL, CodexActivityRootKind)
}

enum LocalActivityDiagnosticStage: String, Codable, Sendable {
    case discovery
    case traversal
    case lineRead
    case fieldDecode
    case reconciliation
    case aggregation
    case readable
}

struct LocalActivityDiagnosticSummary: Codable, Equatable, Sendable {
    let provider: AgentProvider
    let rootKind: CodexActivityRootKind
    let rootExists: Bool
    let rootReadable: Bool
    let regularJSONLFileCount: Int
    let completeLineCount: Int
    let usageClaimCount: Int
    let reconciledRequestCount: Int
    let stage: LocalActivityDiagnosticStage
    let failure: StableLocalActivityFailure?
}
```

The URL never enters `LocalActivityDiagnosticSummary` and is never printed.

## Task 1 — Fix and protect explicit `CODEX_HOME` discovery

- [ ] **Step 1: Add the failing regression.** In the narrowest existing local-activity regression file, provide an environment containing `CODEX_HOME=/private/tmp/isolated-codex-home` and assert the resolved root is `/private/tmp/isolated-codex-home/sessions`; assert absent/blank values resolve to `<home>/.codex/sessions`.
- [ ] **Step 2: Run the regression.** Expect failure because `LocalActivityMonitor.convenience init()` and `CodexLocalActivitySource` currently hard-code `~/.codex/sessions`.
- [ ] **Step 3: Implement `CodexActivityRootResolver`.** Trim no meaningful path characters, reject an empty override, standardize the URL without resolving symlinks, and supply the same resolved URL to the source and observer roots.
- [ ] **Step 4: Run the regression.** Expected exit 0.
- [ ] **Step 5: Record scope honestly.** Mark custom-home discovery fixed, but leave the reported default-home failure open until Tasks 2–4 identify it.

## Task 2 — Add an explicit sanitized diagnostic command

- [ ] **Step 1: Add `--diagnose-local-activity=codex`.** Gate it like the existing one-shot probes: it starts no menu, notification, quota monitor, provider login, Keychain operation, or file observer; it performs one read and exits.
- [ ] **Step 2: Count only safe stages.** Extend traversal/source internals with injected counters and stable error mapping. Never attach a path or source identifier to an error that leaves the actor.
- [ ] **Step 3: Bound output.** JSON-encode exactly one `LocalActivityDiagnosticSummary`. Cap counts at `Int.max`, include no dynamic provider error text, and discard all decoded source state on exit.
- [ ] **Step 4: Prove privacy with source review and a focused test.** Encode a summary and assert its JSON keys are the allowlist above and its value strings contain none of a fabricated path/session/prompt fixture.
- [ ] **Step 5: Build before live use.** Run `swift build --package-path CodexUsageMonitor`; expected exit 0.

## Task 3 — Reproduce the released failure without exporting records

- [ ] **Step 1: Run the diagnostic against the default home.** Record only the emitted summary in `docs/development/codex-local-activity-diagnostic-results.md` under Run / Observed / Not run.
- [ ] **Step 2: Run an isolated explicit-home matrix.** Use a private temporary directory containing sanitized fabricated fixtures for: missing root, unreadable root, empty root, one current valid record, one partial trailing line, one harmless unknown record, one malformed usage claim, and one fork/replay case. Remove only the audit-owned directory after recording counts.
- [ ] **Step 3: Exercise lifecycle boundaries in the signed app.** With enrollment enabled, observe launch scan, file append event, cache rebuild, Token Monitor disable/re-enable, relaunch, day/week aggregation, and app activation. Record presence/count/status only.
- [ ] **Step 4: Locate the first divergence.** Compare expected and observed counts in order: discovered files → complete lines → usage claims → reconciled requests → aggregated state. The earliest mismatching stage is the root-cause boundary; later empty states are consequences.
- [ ] **Step 5: Form one falsifiable hypothesis.** Name the exact schema/permission/cursor/reconciliation condition and identify the smallest synthetic record sequence that reproduces it. Do not proceed with a list of speculative fixes.

## Task 4 — Implement only the confirmed fix

- [ ] **Step 1: Sanitize the reproducer.** Build the smallest fixture containing only the structural fields required to trigger the confirmed failure. Replace all IDs/models/timestamps with fabricated values and verify it contains no copied conversation text or local path.
- [ ] **Step 2: Add one failing regression in the matching suite.** Reader defect → `LocalActivityReaderRegressionTests`; incremental/cache defect → `LocalActivityMonitorRegressionTests`; reconciliation defect → `LocalActivityReconciliationRegressionTests`.
- [ ] **Step 3: Run the single test.** Expected: fail on the released behavior with the confirmed boundary, not a generic assertion.
- [ ] **Step 4: Make the smallest production change.** Preserve strict failure for untrustworthy usage claims and all descriptor/cancellation/privacy invariants. Do not broaden accepted schemas beyond what the reproduced current record requires.
- [ ] **Step 5: Run the single test, the relevant regression file, then the full suite.** Expected: all exit 0.
- [ ] **Step 6: Re-run the sanitized diagnostic.** Expected: the same default-home dataset advances through `.readable` with nonzero usage claims/reconciled requests, or produces the newly specific evidence-backed unavailable state.

## Task 5 — Signed-app acceptance and documentation

- [ ] Build the main macOS scheme with `xcodebuild`; expected exit 0 and no new warnings.
- [ ] Build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh` and verify resources/signature.
- [ ] On the actual default-size menu, open Codex after explicit enrollment and verify Token Monitor publishes current local observations without exposing paths/content.
- [ ] Append one new valid local event through normal Codex use; keep the menu open across the semantic update and verify geometry, hit testing, highlight, keyboard, and VoiceOver remain correct.
- [ ] Exercise missing, unreadable, valid-empty, reading, available, and confirmed failure states in Light and Dark. Record unmanufactured states as Not run.
- [ ] Update `UsageProbe/README.md`, operating notes, follow-up 11, planning board, the active implementation plan, and diagnostic results with the exact cause/fix/evidence.
- [ ] Remove or keep the diagnostic flag by explicit decision. If kept, document its privacy-safe output. If removed, delete only diagnostic-only code after evidence is captured; retain the root resolver and regression.
- [ ] Run `git diff --check`; expected exit 0.

## Diagnosis Completion Criteria

- The first failing boundary is known and reproducible with a sanitized fixture.
- Custom `CODEX_HOME` and default-home behavior are both tested.
- Valid zero is distinguishable from missing/unreadable/malformed.
- The production change is narrower than the diagnostic instrumentation.
- Signed-app behavior, not source inference, proves the user-visible recovery.
