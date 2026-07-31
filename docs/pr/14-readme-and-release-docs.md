# PR 14 — Rewrite the README and record the release and pre-public state

**Branch:** `feature/release-readiness` → `feature/agent-monitor-rename` · 2 commits, 14 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 10 of 10 — merge last.
**State: Ready.** Documentation only; no production code.

## Summary

- Rewrites the README from a short overview into the public entry point.
- Records the real signing state in the release guide, including that the in-flight
  notarization is for a superseded build.
- Adds `before-going-public.md` for what the *repository* needs that the app release
  does not, and the ten PR bodies in this stack.

## Problem and root cause

**1. The README was written for someone who already knew what the app was.** It
described features in prose with no provider matrix, no roadmap, no limitations
section, and no answer to "what does it read, and does anything leave my machine."

**2. The release guide described a state that no longer existed.** It said the
Apple Developer membership was the blocker, the certificate did not exist, the
`.build` bundle was ad-hoc signed, and notarization had never been run. All four
were stale.

**3. Nothing recorded what makes the repository unfit to be public** — as distinct
from what makes the app unfit to release. Those are different lists and were being
tracked as one.

## Scope and non-goals

**Included:** the README rewrite, release-guide corrections, `before-going-public.md`,
planning-board reconciliation, and `docs/pr/5` through `docs/pr/14`.

**Not included:** any code, any behavior, any licence decision. Choosing a licence is
called out as a blocker but is not made here.

## Design and ownership

The README's structure follows the conventions of comparable macOS menu-bar
projects — install first, then requirements, a feature inventory, and a
checkbox roadmap that mixes shipped and planned rather than hiding the queue.

**The Claude credential caveat stays above the fold.** The 2026-07-29 decision was to
publish *with* the caveat disclosed in the README, the app's Data & Privacy page,
and the release notes. Making the repository public raises that build's visibility,
so the disclosure is load-bearing: softening it while "tidying up for a public
audience" would invalidate the decision that permitted shipping at all.

Facts are sourced rather than recalled: the file-and-retention table comes from
`LocalDataInventory`, the roadmap from the planning board, the popover measurements
from the Bug-fix board.

## Privacy, compatibility, and migration

Not applicable — no code changes. The privacy *documentation* is now more complete
than it was: every file the app writes is listed with its contents and retention.

## Regression proof

Not applicable. The applicable check for documentation is link and structure
integrity, which was run: every relative link in every edited document resolves.
The only reported miss is `../../releases/latest`, which is a GitHub-relative URL
that resolves on github.com and not on disk.

## Verification — the whole stack

Each branch was checked out into a **clean worktree** and built and tested from
scratch, so these are clean-clone results rather than working-tree results:

| # | Branch | Build | Tests |
|---|---|---|---|
| 5 | `feature/native-claude-bridge` | ✅ | 298, 0 failures |
| 6 | `feature/token-activity-domain` | ✅ | 299, 0 failures |
| 7 | `feature/token-monitor-popover` | ✅ | 299, **1 failure (0 unexpected)** — see PR 7 |
| 8 | `feature/token-monitor-settings` | ✅ | 299, 0 failures |
| 9 | `feature/release-binary-and-ui-fixes` | ✅ | 300, 0 failures |
| 10 | `feature/token-monitor-day-week` | ✅ | 309, 0 failures |
| 11 | `feature/app-icon-and-plan-name` | ✅ | 316, 0 failures |
| 12 | `feature/repo-asset-hygiene` | ✅ | 316, **1 skipped**, 0 failures |
| 13 | `feature/agent-monitor-rename` | ✅ | 316, **1 skipped**, 0 failures (see flake note) |
| 14 | `feature/release-readiness` | ✅ | 316, **1 skipped**, 0 failures |

Branches 12–14 initially failed with `316 tests, 1 failure (1 unexpected)` in a
clean worktree. That is what surfaced the `MenuBarProviderGlyphTests` problem fixed
in PR 12. From 12 onward the one skip is that test, absent its untracked artwork —
expected, not a failure.

**Flake note.** Branch 13 reported one failure on its first clean run and passed on
two immediate re-runs of the same worktree. Branch 7 showed the same pattern. Both
match the known flake documented in the release guide:
`ClaudeUsageMonitorTests.testReconnectResumesReading` spins on a bounded
`Task.yield()` count and failed twice in roughly 25 runs. Neither occurrence was
captured by name, so the attribution is inference from the pattern — re-run before
concluding anything is broken.

| Other check | State | Result |
|---|---|---|
| Link check across every edited document | Run | All relative links resolve |
| `codesign -dvv` on the built `.app` | Run | Developer ID Application certificate holder and Team ID redacted for public source; `flags=0x10000(runtime)`, `Timestamp=Jul 29, 2026 at 18:09:56` |
| `spctl -a -vv` | Run | `rejected … source=Unnotarized Developer ID` — expected pre-ticket |
| `xcrun stapler validate` | Run | No ticket stapled |
| Notarization | **Not run** | Submitted for the superseded `1.0.0`/`254` build; result outstanding |

## Risks, rollback, and limitations

**Risk.** A README is a promise. It currently states that releases are notarized,
which is not yet true of any published artifact. Publishing the repository before a
notarized `0.0.1` build exists would make that claim false at exactly the moment
someone reads it. Gated as blocker 2 in `before-going-public.md`.

**Rollback.** Revert. Documentation only.

**Limitations — the repository is not yet fit to be public:**

1. **No `LICENSE`.** The README claims non-commercial and nothing enforces it.
2. **The notarized-download claim** is not yet true.
3. Personal coursework sits at the repository root.
4. **Screenshots cannot be committed** after PR 12.
5. The operating-notes document is a maintainer log, not a user guide.
6. The repository name matches neither the old nor the new product name.

## Documentation and review focus

Changed: `README.md`, `docs/development/releasing-on-github.md`,
`docs/development/before-going-public.md` (new), `docs/product/planning-board.md`,
`docs/release-notes/0.0.1.md`, and `docs/pr/5`–`14`.

Focus on **whether any claim in the README is stronger than its evidence** — in
particular the notarization sentence in Install, and anything in Features that
describes a surface the planning board still lists under Verification.
