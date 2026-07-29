# PR 10 — Report the Token Monitor by day or by week

**Branch:** `feature/token-monitor-day-week` → `feature/release-binary-and-ui-fixes` · 1 commit, 18 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 6 of 10 — merge after PR 9.
**State: Draft** — Light/Dark and VoiceOver acceptance unobserved.

## Summary

- Adds a per-agent **Range** choice of **Day** or **Week**, persisted per provider,
  defaulting to Day.
- The week view charts one bar per elapsed day of the **calendar** week the Mac
  uses — not a rolling seven days.
- The card's second header line now names the window (**Today** / **This week**) in
  place of the former fixed `This Mac · observed`.

## Problem and root cause

**Symptom.** The card only ever showed today. "Am I burning through this faster
than last week?" was unanswerable, which is most of why someone watches token spend.

**The subtle part — why a naive week is wrong.** Bucketing by a fixed number of
seconds (7 × 86 400) drifts across a daylight-saving boundary: one calendar day
becomes two partial bars, or two days collapse into one. The user's mental model is
the calendar, so the buckets must step through the calendar.

## Scope and non-goals

**Included:** `TokenMonitorRange`, calendar-stepped bucket edges, the Settings
segmented control in both agent pages, the range-aware header line, and a cache
retention increase from three to fourteen days so a relaunch can still fill a week.

**Not included:** month or custom ranges; any change to reconciliation; any fix for
the popover height, which the week view does not worsen (bar count changes, not
card height).

## Design and ownership

**Both ranges read the same reconciled request set.** Switching rereads no file and
cannot report a figure the current scan did not observe — the range is a
presentation window over data already gathered, not a second collection path.

**Bucket edges step through `Calendar`**, not by a fixed interval, so a
daylight-saving day stays exactly one bar.

The cache retention grew to fourteen days for a specific reason: at three days, a
relaunch could not fill a week view, so the chart would show a truncated week that
looked like reduced usage rather than absent history.

## Privacy, compatibility, and migration

**Privacy.** Unchanged. Longer retention means more hashed request records on disk
for longer — still no paths, session identifiers, or content.

**Compatibility.** Not applicable.

**Migration.** The range preference defaults to Day, so an upgrade looks unchanged.
An unrecognized stored value falls back to Day. Existing three-day caches simply
extend; nothing is rewritten.

## Regression proof

`testUnknownStoredRangeFallsBackToDay` — an unrecognized persisted range must not
leave the card blank or crash. Calendar bucketing is covered by tests that step a
week containing a daylight-saving transition and assert exactly seven bars.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | Build complete |
| `swift test` at this branch tip | Run | 309 tests, 0 failures |
| Daylight-saving week produces exactly seven bars | Run | Passes |
| Unknown stored range falls back to Day | Run | Passes |
| Both ranges in the signed app, Light and Dark | **Not run** | |
| Settings row disabled state with the card hidden | **Not run** | |
| VoiceOver on the range-dependent chart labels | **Not run** | The labels change with the range, so the accessibility text is range-dependent and untested |

## Risks, rollback, and limitations

**Risk.** Fourteen days of cached requests is roughly 4.7× the previous file. For a
heavy user this is a larger JSON file read at launch; it is bounded by retention but
not by size.

**Rollback.** Revert. The range key becomes inert and the cache self-trims back.

**Limitation.** A partially elapsed week shows fewer bars than seven. That is
correct but can read as a drop in usage at a glance.

**Provenance note.** The roadmap's phase-7 acceptance says the card *always* reads
`This Mac · observed`. That line is now the range instead, by direct 2026-07-29
direction. Recorded so the roadmap and the implementation are not mistaken for
having drifted.

## Documentation and review focus

Changed: `CONTEXT.md`, the token-activity plan, the planning board, `how-to.md`.

Focus on the **calendar stepping** — specifically the week containing a
daylight-saving transition, and the first and last buckets of a partially elapsed
week.
