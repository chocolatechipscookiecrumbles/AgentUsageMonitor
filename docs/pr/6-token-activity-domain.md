# PR 6 — Token activity domain and per-provider reconciliation

**Branch:** `feature/token-activity-domain` → `feature/native-claude-bridge` · 8 commits, 24 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 2 of 10 — merge after PR 5.
**State: Ready.** No UI is added, so there is nothing here that needs signed-app
acceptance. **This is the highest-risk PR in the stack** — see review focus.

## Summary

- Defines the token-request domain and a source protocol, then implements
  reconciliation for Codex and Claude Code's local record files.
- Both providers normalize to the same **hashed** request identity. No file path,
  session identifier, prompt, or response enters the model.
- Pure model and reader work only — nothing is rendered, scheduled, or cached yet.

## Problem and root cause

**Symptom.** Quota answers "how much is left," never "what did I spend it on." Both
CLIs already write per-request records locally, so the information sat on disk with
no reader.

**Root cause of the hard part** — the two record formats fail in opposite ways, and
neither can be summed naively:

- **Codex** writes **cumulative** totals per session and forks a session on
  branching. Adding the records double-counts everything before the fork point.
- **Claude Code** writes **streaming** records, and a sidechain repeats a request
  that was already emitted. Adding those double-counts the repeated request.

Each needs a different correction to reach the same answer: the set of distinct
requests actually made.

## Scope and non-goals

**Included:** `LocalActivityModels` (the request domain), `LocalActivitySource`
(the protocol), `LocalActivityJSONLReader`, `CodexLocalActivitySource`,
`ClaudeLocalActivitySource`, and their reconciliation regression tests.

**Not included:** file watching, caching, scheduling, any view, and any Settings
control. Those are PRs 7 and 8. Nothing in this PR runs on its own.

## Design and ownership

Each provider owns its own reconciler because the failure modes are not shared;
a single "generic" reader would have to branch on provider at every step anyway.
Both produce the same normalized request type, so everything downstream is
provider-agnostic.

Request identity is **hashed at the boundary**, inside the source, not later. That
makes it structurally impossible for an un-hashed identifier to reach the cache or
the view, rather than relying on every future call site to remember.

The JSONL reader tolerates a truncated final record, because the CLI may be
mid-write when a scan runs.

## Privacy, compatibility, and migration

**Privacy — the central constraint of this PR.** The records being read contain
prompt and response content. The normalized model carries only hashed request
identity, timestamp, model name, and token counts. Privacy-sentinel tests assert
that prompt and response text cannot enter the snapshot.

**Compatibility.** Both formats are externally controlled and can change without
notice. Fixtures cover the shapes observed to date: valid records, unknown additive
fields, missing optional and required fields, a truncated final record, repeated
scans, appends, inconsistent model identifiers, and totals near integer boundaries.

**Migration.** Not applicable — nothing is persisted yet.

## Regression proof

`LocalActivityReconciliationRegressionTests` recreates the two real over-counts:

- **Codex fork double-count** — a session that forks produces cumulative totals on
  both sides. The test asserts the differenced result, and fails against naive
  summing.
- **Claude sidechain duplicate** — `477b3be "fix: preserve unique sidechain
  activity"` came from a sidechain record being dropped *and* a duplicate being
  kept; the test pins both directions.

Three further commits (`00aea2c`, `c4eaa89`, `1458043`) harden the Codex path:
evidence validation, reading within the descriptor, and record limits. Each carries
its own case.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | See the stack table in PR 14 |
| `swift test` at this branch tip | Run | See the stack table in PR 14 |
| Reconciled output compared against live records on this Mac | Observed | Both providers reconcile to plausible totals |
| Comparison against an independent tool (ccusage / Tokscale) | **Not run** | Would be useful evidence; agreement is not the product contract |

## Risks, rollback, and limitations

**Risk — the most credible failure in the whole stack.** A record shape outside the
fixtures reconciles to a wrong number that *looks* plausible. There is no
authoritative figure to check against, so a silent over- or under-count would not
announce itself. Mitigation is fixture breadth, not detection.

**Rollback.** Revert. Nothing is persisted or rendered at this point in the stack.

**Limitation.** Reconciliation is only as correct as the observed formats. Treat the
figures as *observed on this Mac*, never as provider-authoritative billing.

## Documentation and review focus

Changed: `AGENTS.md`, `CONTEXT.md`, `UsageProbe/README.md`, the token-activity plan,
and `docs/adr/0001-read-local-token-activity-automatically.md`.

**Please review this one properly.** Specifically: can a Codex fork or a Claude
sidechain still be counted twice under a record shape the fixtures do not cover?
That is the one place in this stack where a wrong answer looks right.
