# PR 7 — Show the Token Monitor in the menu popover

**Branch:** `feature/token-monitor-popover` → `feature/token-activity-domain` · 5 commits, 24 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 3 of 10 — merge after PR 6.
**State: Draft** — signed-app acceptance of the card is unobserved, and this PR
introduces the popover height problem.

## Summary

- Adds `LocalActivityMonitor`: scans incrementally on filesystem events rather than
  polling, and caches reconciled requests so a relaunch renders before re-reading.
- Renders the card in both provider tabs, independent of quota, so it keeps working
  while a provider is disconnected.
- **Introduces the popover height problem.** The card makes the Codex tab tall
  enough to clip on smaller displays. Named here rather than discovered later.

## Problem and root cause

**Symptom.** PR 6 produced correct reconciled requests that nothing displayed.

**Second problem, found during this work.** A naive implementation re-reads whole
record files on a timer. These files grow continuously, and the popover opens often,
so that would be both slow and pointless — the records only change when a CLI writes.

## Scope and non-goals

**Included:** `LocalActivityMonitor` (the read cycle owner), `LocalActivityCache`
(persistence across launches), `LocalActivityFileObserver` (event-driven scanning),
`ProviderTokenActivityPresentation`, `ProviderTokenActivityCard`, and wiring through
`QuotaViewModel` into both provider tabs.

**Not included:** any Settings control over the card (PR 8), the Day/Week range
(PR 10), and any fix for the height it introduces.

## Design and ownership

`LocalActivityMonitor` is the single read-cycle owner, in the same shape as
`QuotaMonitor` and `ClaudeUsageMonitor`. `QuotaViewModel` remains the one state
owner the UI observes; the card is a consumer and owns no scheduler.

**Scanning is event-driven and incremental.** The observer watches the record
directories; a scan resumes from the last offset rather than re-reading the file.
The cache stores only the reconciled values the card already displays — not raw
records — so a relaunch can render immediately and the cache cannot become a second
source of truth.

The card is deliberately **independent of quota state**. Token history is a fact
about what happened locally; it should not blank out because a provider is
disconnected or a refresh failed.

## Privacy, compatibility, and migration

**Privacy.** The cache stores hashed request identities, timestamps, models, and
token counts — no file paths, session identifiers, or record contents. Reading is
local; nothing is uploaded and no tokens are spent producing the view.

**Compatibility.** Inherits PR 6's exposure to externally controlled record formats.

**Migration.** The cache file is new and absent-safe; a first run after upgrade
simply scans. An older build ignores it.

## Regression proof

`122fb1c` and `b8c0501` are layout and pairing changes with no prior failure.
The reconciliation guarantees are covered in PR 6.

**One test failure was observed at this branch tip during stack verification:**
`Executed 299 tests, with 1 failure (0 unexpected)`. The count of *unexpected*
failures is zero, and the same suite passes at the immediately following branch tip
(PR 8, 299 tests, 0 failures) with no test-affecting change between them. The most
likely explanation is the known flake documented in the release guide —
`ClaudeUsageMonitorTests.testReconnectResumesReading`, which spins on a bounded
`Task.yield()` count and failed twice in roughly 25 runs. **This was not confirmed
by re-running the branch**, so treat it as unexplained rather than dismissed.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | Build complete |
| `swift test` at this branch tip | Run | 299 tests, **1 failure (0 unexpected)** — see above |
| Card rendered against live records, both providers | Observed | Both reconcile; card renders in both tabs |
| Incremental rescan on file change | Observed | Scans on write, not on a timer |
| Popover visual, keyboard, and VoiceOver acceptance | **Not run** | Deliberately withheld: the height problem this PR introduces is unresolved, so accepting the card's appearance would be accepting a state that clips |

## Risks, rollback, and limitations

**Risk.** The file observer is a long-lived resource. A leaked observer or a scan
that overlaps itself would burn CPU in a menu-bar app that is always running.
Scans coalesce; teardown is not independently verified.

**Rollback.** Revert. The cache file becomes orphaned but harmless, and no quota
behavior is touched.

**Limitation — the important one.** With the card at its tallest, the Codex tab runs
to roughly 915 points against about 775 usable at 1280×800. The popover does not
scroll, by design, so the tallest real state clips on smaller displays. This is
tracked on the Bug-fix board and **deferred by direction**; four candidate fixes are
recorded and none is chosen. Signed-app acceptance stays unobserved until it is
resolved.

## Documentation and review focus

Changed: the token-activity plan, `docs/adr/0001-read-local-token-activity-automatically.md`,
`CONTEXT.md`, and the planning board.

Focus on **observer lifetime and scan coalescing** — whether a rapid series of
record writes can start overlapping scans, and whether the observer is released
when a provider stops being monitored.
