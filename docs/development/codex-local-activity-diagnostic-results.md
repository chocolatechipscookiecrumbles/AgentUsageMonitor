# Codex local-activity diagnostic results

Sanitized evidence for [product follow-up 11](../product/follow-ups.md#11-codex-token-monitor-can-fail-to-read-local-usage).
No record content, prompt, response, path, session identifier, turn identifier,
or token value appears here. Only structural key names, record-type names, counts,
and presence booleans were collected.

## Run — 2026-08-04

Read-only inspection of the default root (`CODEX_HOME` unset, so
`~/.codex/sessions`) on the machine that reported the failure. The reader's throw
conditions were re-implemented in a Python probe and replayed over the whole
root; the probes are kept out of the repository because they exist only to
produce the counts below.

**Root:** present, readable, 261 `.jsonl` files across `2026/04`–`2026/08`.
Recent activity is present: 9 files modified since 2026-08-01, 2 on the day of
the run. Discovery is therefore not the failure.

## Observed

| Stage | Result |
| --- | --- |
| Discovery | Root exists and is readable. **Pass.** |
| Traversal | 261 regular `.jsonl` files, no non-JSONL files, no symlink refusals. **Pass.** |
| Line read | 0 undecodable JSON lines out of every line read. **Pass.** |
| Field decode | 26,192 usage-bearing `token_count` records. 0 missing usage fields, 0 negative values, 0 `cached > input`, 0 `reasoning > output`. **Pass.** |
| Reconciliation | **2 of 261 files throw.** First divergence. |
| Aggregation | Never reached — the throw aborts the whole-root scan. |

**First failing boundary: reconciliation input, in `FileParseState.consume`.**

```swift
guard let rawTimestamp = record.timestamp,
      let timestamp = CodexLocalActivitySource.date(rawTimestamp),
      let turnID = payload.turnID ?? currentTurnID
else { throw CodexLocalActivityFailure.malformedUsage }
```

Codex has **never** written `turn_id` or `turnId` on a `token_count` payload. In
all 261 files the payload keys are exactly `info`, `rate_limits`, `type` — across
every CLI version present in the root (`0.125.0-alpha.3` through `0.146.0`). The
reader therefore depends entirely on `currentTurnID`, latched from the preceding
`task_started` record, which does carry `turn_id` in every month observed.

That latch is empty in a **resumed session**, which replays prior usage before
the first new turn begins. Two files dated `2026/07/30` — the day before 0.0.1
was published — have their first usage-bearing `token_count` at line 5 and their
first `task_started` at line 25. `currentTurnID` is still `nil`, and the guard
throws.

**The throw is not isolated to its file.** Both `catch` blocks in
`LocalActivityJSONLReader.swift` close a descriptor and rethrow; nothing between
`consume` and `CodexLocalActivitySource.scan`'s catch-all interrupts it, so the
scan returns `.unsafeToRead` for the entire root. The card shows
**"Activity unavailable — Local records couldn't be read safely."**

**2 unreadable files blank 259 readable ones.** `parseCache` lives only in
memory, so every launch re-reads from offset 0 and reproduces the failure. The
state is permanent, not intermittent, which matches the report.

`turn_id` is used only as a component of the request-identity digest. No
arithmetic, ordering, or reconciliation decision depends on it, and
`UsageEvent.turnID` is already `String?`. The strictness was not protecting
trustworthy reconciliation.

## Second finding — fork baselines are silently skipped

Not a failure; a wrong number. Codex now writes `parent_thread_id` on
`session_meta`. The reader recognizes only `forked_from_id`,
`parent_session_id`, and their camelCase spellings, so it does not see the newer
key.

| Fork key | Occurrences | Resolvable to a present file |
| --- | --- | --- |
| `parent_thread_id` | 196 | 196 |
| `forked_from_id` | 38 | 38 |

All 234 parent references resolve, so nothing is unresolvable — but 196 forked
sessions receive no parent baseline subtraction and are **over-counted**. This is
a separate defect with a separate fix and is deliberately not bundled into the
recovery change.

## Not run

- Signed-app observation. `Resources/Assets.xcassets/` is excluded from this
  repository, so `build-app.sh` fails at `actool` before signing. Restoring the
  catalog from the private copy is a prerequisite.
- The isolated explicit-`CODEX_HOME` fixture matrix (missing, unreadable, empty,
  partial trailing line, unknown record type, malformed usage claim, fork/replay).
- Lifecycle boundaries: launch scan, file-append event, cache rebuild, Token
  Monitor disable/re-enable, relaunch, day/week aggregation, activation.

## Conclusion

One falsifiable cause, reproduced by a specific structural sequence: **a
usage-bearing `token_count` that precedes the session's first `task_started`**.
The smallest reproducer is a two-record file — one `token_count` carrying
`info.last_token_usage`, with no `task_started` before it.

Two changes follow, decided 2026-08-04:

1. Stop requiring a turn identifier for a `token_count` that carries usage.
2. Stop letting one uninterpretable file fail the whole root: skip it and report
   the files that did parse. A root whose every file fails stays `.unsafeToRead`.

The `CODEX_HOME` discovery defect recorded in the plan is real and independently
reproducible, but it is **not** this failure: this machine has `CODEX_HOME` unset
and reads the default root correctly.

## Fix verified — 2026-08-04

Two changes landed: a usage-bearing `token_count` with no resolvable turn
identifier is now recorded rather than refused, and a file this build cannot
interpret is skipped instead of failing the whole root. Cancellation and I/O
failures still propagate; a root whose every file fails stays `.unsafeToRead`.

Measured with the real `CodexLocalActivitySource` against the live default root:

| | Before | After |
| --- | --- | --- |
| Status | `.unsafeToRead` | `.readable` |
| Reconciled requests | 0 | 14,534 |
| Files parsed | 0 of 261 | 261 of 261 |

Three regressions protect it: usage before the first `task_started` is counted;
one uninterpretable file does not blank its readable neighbour; a root where
every file fails is still `.unsafeToRead`. All fail on the released behavior.

**Observation, not a defect:** that cold scan took ~53 s for 261 files and 26,192
usage records. It runs off the main actor and the launch cache republishes the
previous result meanwhile, so nothing blocks or blanks — but it is worth
measuring before the next release.
