# PR 12 — Keep binary and design assets out of version control

**Branch:** `feature/repo-asset-hygiene` → `feature/app-icon-and-plan-name` · 3 commits, 36 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 8 of 10 — merge after PR 11.
**State: Ready.** Read the consequences first — this PR trades something real away.

## Summary

- GitHub now carries code, docs, and plan files only. `assets/`, the app's own
  `Assets.xcassets` catalog, and every image, design-source, font, media, and
  archive extension are ignored; the 30 already-committed files are untracked and
  remain on disk.
- **Consequence:** a clean clone can `swift build` and `swift test`, but cannot
  `build-app.sh` until the asset catalog is supplied separately.
- Also marks the release scripts executable and replaces absolute `/Users` paths in
  three documents.

## Problem and root cause

**Symptom / request.** Binary and design assets — Sketch sources, icon exports,
PDFs, SVGs — were accumulating in a repository intended to hold code and its
reasoning. Directed on 2026-07-29: assets stay local.

**A second, real problem this exposed.** `MenuBarProviderGlyphTests` reads the asset
catalog **directly from the source tree**, because the catalog is compiled by
`build-app.sh` rather than declared as a SwiftPM resource — so there is no test
bundle to read it from. Untracking the catalog made that test fail on a clean clone
with `NSCocoaErrorDomain Code=260 … Contents.json couldn't be opened`.

This was found by checking out each branch of this stack into a clean worktree and
running the suite, not by reasoning about it. Working-tree runs pass because the
files are still on disk locally.

## Scope and non-goals

**Included:** the `.gitignore` rules, `git rm --cached` for 30 files, the
`XCTSkipUnless` guard in `MenuBarProviderGlyphTests`, `chmod +x` on the two release
scripts, and repo-relative paths in `docs/claude-usage-verification.md`,
`how-to.md`, and the menu-bar MVP plan.

**Not included:** deleting anything from disk; renaming or moving the assets; a
screenshots exception for the README (see limitations).

## Design and ownership

`assets/course.css` is the **one exception**, re-included with a negation: it is a
stylesheet, and the tracked pages in `lessons/` and `reference/` link to it. A
tracked page whose stylesheet is untracked renders unstyled on GitHub.

The glyph test **skips** rather than failing when the imageset is absent. The
alternative was un-ignoring four imagesets, which would partly reverse the
directive. Skipping keeps the directive intact and keeps a clean clone green; the
test still runs and still discriminates on any machine that has the artwork —
which is any machine that can build the `.app` at all.

**If CI is ever added, revisit this.** A skipped test in CI is unprotected, and the
right answer there is probably to un-ignore the four imagesets (roughly 40 KB).

## Privacy, compatibility, and migration

**Privacy.** Incidentally positive: fewer binaries published. A scan for secrets,
emails, and probe output over the tracked set came back clean — every `sk-ant-…`
hit is a fixture or a `REPLACE_ME` placeholder.

**Compatibility.** Not applicable to the app. Real for contributors: see below.

**Migration.** Existing clones keep their working copies; the files simply stop
being tracked. There is no way to recover them from git after this merge, so the
local copies are now the only copies.

## Regression proof

The `XCTSkipUnless` guard is verified in both directions:

- **With the catalog present** (this working tree): `swift test --filter
  MenuBarProviderGlyphTests` → 1 test, 0 failures. It runs, it does not skip.
- **Without it** (clean worktree at this branch): the suite went from
  `316 tests, 1 failure (1 unexpected)` to green.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` in a clean worktree at this tip | Run | Build complete |
| `swift test` in a clean worktree at this tip | Run | Green after the skip guard; **1 unexpected failure before it** |
| Glyph test with the catalog present | Run | 1 test, 0 failures — runs rather than skips |
| `git ls-files -i -c --exclude-standard` | Run | Empty — nothing tracked is ignored |
| `git status -uall` | Run | Empty — nothing untracked is left unignored |
| Secrets / email / probe-output scan over tracked files | Run | Clean |
| `build-app.sh` from a clean clone | **Not run** | It cannot work by design; stated rather than tested |

## Risks, rollback, and limitations

**Risk — the honest one.** Anyone who clones this repository cannot build a
distributable `.app`. `actool` has no catalog to compile and the `.icns` step fails.
That is a deliberate trade, not an oversight, and it makes the project effectively
single-machine for releases until the assets are supplied another way.

**Rollback.** Reverting this PR restores the `.gitignore` **and** the 30 files,
since the untracking is part of the same commit.

**Limitations:**

- **README screenshots cannot be committed.** For a menu-bar app this is the most
  costly omission — comparable projects lead with one. Fixing it needs an explicit
  `!docs/screenshots/` exception or off-repo hosting. Tracked in
  `docs/development/before-going-public.md`.
- Two course HTML pages still contain absolute `/Users` paths in shell snippets.
- The glyph regression is unprotected on any machine without the artwork.

## Documentation and review focus

Changed: `.gitignore`, `docs/development/before-going-public.md`, the planning
board, and the three documents with absolute paths.

Focus on the **skip-versus-un-ignore decision**. If a skipped regression test is
not acceptable to you, un-ignoring the four imagesets is a two-line change and this
is the moment to make it.
