# Codex Local Activity Recovery Diagnosis Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `systematic-debugging` and `diagnosing-bugs` throughout. Use `test-master` only after the released failure is reproduced. Do not implement a speculative parser fix. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the 0.0.1 Codex Token Monitor failure, identify the exact discovery/read/decode/reconciliation boundary, and protect the smallest evidence-backed fix.

> ## Diagnosis complete — 2026-08-04
>
> **The cause is confirmed and no longer speculative.** Full sanitized evidence:
> [`docs/development/codex-local-activity-diagnostic-results.md`](../../development/codex-local-activity-diagnostic-results.md).
>
> A `token_count` record that carries usage but is not preceded by a
> `task_started` makes `FileParseState.consume` throw `malformedUsage`, because
> Codex never writes `turn_id` on `token_count` payloads and the latched
> `currentTurnID` is still `nil`. This happens in **resumed sessions**, which
> replay prior usage before the first new turn. Nothing isolates that throw to its
> file, so `scan` returns `.unsafeToRead` for the whole root: **2 files out of 261
> blank the 259 that parse perfectly**, on every launch, permanently.
>
> `turn_id` is only a component of the request-identity digest — no arithmetic
> depends on it, and `UsageEvent.turnID` is already `String?`. The strictness was
> not protecting trustworthy reconciliation, so the Global Constraint below about
> establishing which case occurred is **satisfied**: this is legitimate data the
> reader wrongly rejects, not untrustworthy data.
>
> Ruled out by evidence, not inference: discovery, permissions, traversal, line
> read, and field decode all pass across 26,192 usage records (0 undecodable
> lines, 0 missing fields, 0 invariant violations).
>
> **Tasks 2 and 3 are superseded** — the standalone `--diagnose-local-activity`
> command was scaffolding for finding this, and a read-only external probe found
> it without adding shipping code. Task 1 (`CODEX_HOME`) remains valid but is a
> *different* defect: this machine has `CODEX_HOME` unset. Task 4 is replaced by
> Task 4′ below.
>
> **Scope decided 2026-08-04:** fix both the rejection and the fragility behind
> it. The `parent_thread_id` fork-key defect found during diagnosis (196 sessions
> silently over-counted) is real but deliberately **not** bundled here.

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

## Task 2 — Superseded

The `--diagnose-local-activity=codex` command was scaffolding for locating the
first failing stage. A read-only external probe located it without adding any
shipping code, so no diagnostic flag ships and there is none to remove later.
Evidence is recorded in `docs/development/codex-local-activity-diagnostic-results.md`.

## Task 3 — Superseded

Reproduction is complete; see the diagnosis banner above and the results
document. The first divergence is reconciliation input, in `FileParseState.consume`.

## Task 4′ — Implement the confirmed fix

- [x] **Step 1: Add the failing regression for the rejected record.** In
  `LocalActivityReaderRegressionTests`, build the smallest sanitized fixture that
  reproduces it: one `token_count` line carrying `info.last_token_usage`, with no
  preceding `task_started`. All identifiers, models, and timestamps fabricated;
  no copied conversation text and no local path. Assert the scan is `.readable`
  with one reconciled request.
- [x] **Step 2: Add the failing regression for the blast radius.** A root of two
  files — one that parses and one that cannot be interpreted at all — must report
  the good file's activity rather than `.unsafeToRead`. This is the property that
  turns a single bad record into a blank card, and it is the reason the released
  failure was total rather than partial.
- [x] **Step 3: Run both.** Expect failure on the released behavior with the
  confirmed boundary: `malformedUsage` from the missing turn identifier, and a
  whole-root `.unsafeToRead` from the uninterpretable file.
- [x] **Step 4: Accept a usage record with no resolvable turn identifier.** Keep
  the timestamp requirement strict — a usage claim with no time cannot be placed
  in any window. `UsageEvent.turnID` is already optional and the identity digest
  already frames an absent value, so nothing downstream changes shape.
- [x] **Step 5: Isolate per-file parse failures in the traversal.** A file whose
  records this build cannot interpret is skipped; the remaining files still
  report. Cancellation, `ReaderFailure`, and `TraversalFailure.unsafeFilesystem`
  keep propagating — an I/O or filesystem problem is still a root-level failure
  and must not be silently swallowed as "one odd file".
- [x] **Step 6: Keep a wholly unreadable root distinguishable.** If every file
  with content fails to parse, the root stays `.unsafeToRead`. A valid empty root
  stays `.readable` with zero requests, and a missing root stays
  `.localRecordsMissing`. These three must not collapse into each other.
- [x] **Step 7: Preserve every existing invariant.** Descriptor-relative
  `O_NOFOLLOW` traversal, field-scoped decoding, opaque identities, bounded
  app-owned cache, actor isolation, cancellation/generation guards, and cache
  purge on collection disable are unchanged. Strictness stays for a usage claim
  that is genuinely untrustworthy: missing token fields, negative values,
  `cached > input`, `reasoning > output`, and a claim with neither last nor total.
- [x] **Step 8: Note the shared effect on Claude.** The traversal is shared with
  `ClaudeLocalActivitySource`, so per-file isolation applies there too. That is
  intended — the same fragility exists on that path — but the Claude regressions
  must be re-run rather than assumed.
- [x] **Step 9: Run both new tests, the local-activity regression files, then the
  full suite.** Expected: all exit 0.
- [x] **Step 10: Re-verify against the real root.** Replay the reader's throw
  conditions over the default home and confirm 261 of 261 files now parse, with
  nonzero reconciled requests.

**Observed 2026-08-04.** `swift build` exits 0. The three new regressions fail on
the released behavior with the confirmed boundary (`.unsafeToRead` where
`.readable` is required) and pass after the change. Full suite: 332 tests, 0
failures, 1 pre-existing skip.

Against the live default root, using the real `CodexLocalActivitySource` rather
than a simulation:

| | Before | After |
| --- | --- | --- |
| Status | `.unsafeToRead` | `.readable` |
| Reconciled requests | 0 | 14,534 |
| Files parsed (cursors) | 0 | 261 of 261 |

One observation worth recording, not a defect: that cold scan of 261 files and
26,192 usage records took ~53 s. It runs on an actor off the main thread, and
`LocalActivityCache` republishes the previous result at launch so the card is not
blank while it runs — but it is slow enough to be worth measuring before the next
release rather than discovering later.

## Task 5 — Signed-app acceptance and documentation

- [x] `swift build` — **observed** exit 0, no new warnings.
- [x] Verify against the live default root — **observed** `.readable`, 14,534 reconciled requests, 261 of 261 files parsed (was `.unsafeToRead`, 0, 0).
- [ ] Build the main macOS scheme with `xcodebuild`. **Not run.**
- [ ] Build the signed `.app` with `CodexUsageMonitor/Scripts/build-app.sh` and verify resources/signature. **Blocked** — `Resources/Assets.xcassets/` is excluded from this repository, so `actool` fails before signing.
- [ ] On the actual default-size menu, open Codex after explicit enrollment and verify Token Monitor publishes current local observations without exposing paths/content.
- [ ] Append one new valid local event through normal Codex use; keep the menu open across the semantic update and verify geometry, hit testing, highlight, keyboard, and VoiceOver remain correct.
- [ ] Exercise missing, unreadable, valid-empty, reading, available, and confirmed failure states in Light and Dark. Record unmanufactured states as Not run.
- [ ] Update `UsageProbe/README.md`, operating notes, follow-up 11, planning board, the active implementation plan, and diagnostic results with the exact cause/fix/evidence.
- [x] Remove or keep the diagnostic flag by explicit decision. **Decided: none ships.** A read-only external probe located the cause, so no diagnostic-only code was ever added and there is nothing to remove. The root resolver from Task 1 remains outstanding as a separate defect.
- [ ] Superseded wording: If kept, document its privacy-safe output. If removed, delete only diagnostic-only code after evidence is captured; retain the root resolver and regression.
- [ ] Run `git diff --check`; expected exit 0.

## Diagnosis Completion Criteria

- The first failing boundary is known and reproducible with a sanitized fixture.
- Custom `CODEX_HOME` and default-home behavior are both tested.
- Valid zero is distinguishable from missing/unreadable/malformed.
- The production change is narrower than the diagnostic instrumentation.
- Signed-app behavior, not source inference, proves the user-visible recovery.
