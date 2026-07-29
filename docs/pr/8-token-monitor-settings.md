# PR 8 — Per-agent Token Monitor settings

**Branch:** `feature/token-monitor-settings` → `feature/token-monitor-popover` · 9 commits, 23 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 4 of 10 — merge after PR 7.
**State: Draft** — signed-app Settings and popover acceptance is unobserved.

## Summary

- Gives each agent its own Token Monitor section in Settings: which parts of the
  card render, and whether the provider is collected at all.
- Turning collection off **purges that provider's cache** rather than leaving stale
  data on disk.
- Renames the feature from "Dashboard"/"token activity" to **Token Monitor** across
  the card header, `CONTEXT.md`, and the operating docs.

## Problem and root cause

**Symptom.** The card was all-or-nothing. A user who wanted the total but not the
chart, or who did not want one provider's records read at all, had no control — and
the card is the single largest contributor to popover height.

**Cause.** The card shipped (PR 7) with no preference surface, and
`LocalActivityMonitor` had no notion of a disabled provider: it scanned both
because both existed.

## Scope and non-goals

**Included:** per-provider preferences in `AppSettings`, `TokenMonitorSection`,
section-aware rendering in `ProviderTokenActivityCard`, collection gating with cache
purge in `LocalActivityMonitor`/`LocalActivityCache`, the shared
`AgentTokenMonitorSection` used by both agent pages, and the naming change.

**Not included:** the Day/Week range (PR 10), and any fix for the popover height —
these toggles are a *workaround* for it, not a solution, and the plan says so.

## Design and ownership

Preferences are per provider, not global, because the two providers' records differ
in size and a user may trust one and not the other. The same
`AgentTokenMonitorSection` view is used by both agent pages, so the two cannot drift
apart.

**Collection gating is enforced in the monitor, not the view.** A hidden card that
still scanned files would be a privacy defect dressed as a display preference. Off
means no read, and the purge means no residue.

## Privacy, compatibility, and migration

**Privacy.** This PR only *reduces* what is read. Disabling a provider stops the
scan and deletes its cached requests.

**Compatibility.** Not applicable — no external format is touched.

**Migration.** New preference keys default to enabled with all sections visible, so
an upgrade looks exactly like PR 7 until the user changes something. A rollback
ignores the keys.

## Regression proof

`2aa2992 "fix: write the activity cache one provider at a time"` is the real defect
here: a single shared write path let one provider's completed scan clobber the
other's cached requests, so a relaunch could show one provider's history as empty.
Its test drives two providers through interleaved scans and asserts both survive.

The remaining commits are feature work with no prior failure to reproduce, so per
the repository's testing policy they add no automated coverage.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | See the stack table in PR 14 |
| `swift test` at this branch tip | Run | See the stack table in PR 14 |
| Per-provider cache isolation | Run | Regression test passes; fails against the shared write path |
| Settings sections in the signed app, Light and Dark | **Not run** | |
| Popover card reflecting each toggle | **Not run** | Blocked behind the deferred height problem |
| VoiceOver over the new Settings rows | **Not run** | |

## Risks, rollback, and limitations

**Risk.** A purge on disable is destructive by design. If a user toggles a provider
off and back on, the history before the toggle is gone and the card refills only
from what the records still contain.

**Rollback.** Revert. Preference keys become inert; caches are unaffected.

**Limitation.** These toggles let a user *avoid* the popover height problem. They do
not fix it, and the default state is still the tall one.

## Documentation and review focus

Changed: `CONTEXT.md`, the Token Monitor settings plan, the token-activity plan,
`how-to.md`, and the planning board.

Focus on the **gating boundary**: confirm no read path survives when a provider is
disabled, including the initial scan at launch and the file-observer callback.
