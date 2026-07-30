# PR 9 — Optimized release binary, popover shortcuts, and the Codex glyph fix

**Branch:** `feature/release-binary-and-ui-fixes` → `feature/token-monitor-settings` · 3 commits, 27 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 5 of 10 — merge after PR 8.
**State: Draft** — three signed-app checks remain.

## Summary

- `build-app.sh` now builds `-c release` and installs both the app executable and
  the bundled bridge from `.build/release/`. The shipped binary was a debug build.
- Fixes the Codex menu-bar glyph rendering as a **solid block**.
- Adds key equivalents to the four popover footer commands, and Data & Privacy /
  Diagnostics actions that were previously read-only pages.

## Problem and root cause

**1. The release binary was a debug binary.** `build-app.sh` installed from
`.build/debug/`. Nobody noticed because a debug build runs fine — it is just
slower and larger than what should be distributed.

**2. The Codex menu-bar glyph rendered as a filled block.**
`MenuBarLabelView` draws its provider glyph with `.renderingMode(.template)`, which
paints *every* non-transparent pixel with the tint. The menu bar was naming
`AgentProvider.settingsAssetName`, whose Codex artwork is a full-bleed opaque square
— **measured 97% opaque at 64pt**, against well under 60% for the other two glyphs,
which are correctly transparent. Templating an opaque square produces a square.

**3. Data & Privacy and Diagnostics were read-only.** They described local data and
refresh history with no way to inspect, copy, or clear any of it.

## Scope and non-goals

**Included:** release-configuration build, the `CodexMenuBar` imageset with a
template rendering intent reached through a new `AgentProvider.menuBarAssetName`,
`MenuActionShortcut` as the single catalog for displayed symbol and registered
binding, and the Data & Privacy / Diagnostics actions.

**Not included:** editing shortcut assignments — deliberately deferred, and the
Settings page says so; deleting local data from the Data & Privacy page — deferred
by decision, and the page says so.

## Design and ownership

**The glyph fix does not touch the colored settings artwork.** A new
`menuBarAssetName` is added beside the existing `settingsAssetName`, so every
surface that legitimately wants the colored mark keeps it. Only the menu bar and
its preview move to the templated artwork.

**One shortcut catalog.** `MenuActionShortcut` supplies both the symbol shown in the
footer and the binding that registers, so the displayed list cannot drift from what
actually fires — the failure mode this design is chosen to prevent.

**Copy Report renders from the same `SettingsStatus` the page draws**, so a pasted
report cannot disagree with the page it was copied from.

## Privacy, compatibility, and migration

**Privacy.** **Export Local Data…** writes every documented store to one
user-chosen file. It marks stores that were never written as *unavailable* rather
than omitting them, so the export cannot imply the app holds less than it does.
Diagnostics carry stable classifications only — never raw provider error text or
quota values.

**Compatibility and migration.** Not applicable — no persisted format changes.

## Regression proof

`MenuBarProviderGlyphTests` renders the artwork the **menu bar** names and asserts
opaque coverage below 90%. It **fails against the old asset** (97%) and **passes
against the new one**, so any future substitution of opaque artwork fails in the
test rather than in the menu bar.

Note: that test reads the asset catalog from the source tree. PR 12 untracks the
catalog and makes the test skip when it is absent; see that PR.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | Build complete |
| `swift test` at this branch tip | Run | 300 tests, 0 failures |
| Glyph regression | Run | Fails on the old asset, passes on the new |
| `build-app.sh` produces a release binary | Run | Installs from `.build/release/` |
| Codex glyph in Light and Dark menu bars, and in the General preview card | **Not run** | |
| Each shortcut fires; none bound while the preference is off | **Not run** | |
| Export save panel, copied report text, cleared empty states | **Not run** | |

## Risks, rollback, and limitations

**Risk.** The export writes a file containing the user's local quota and token
history to a location they choose. It is their data going where they asked, but it
is the one action in this PR that moves data out of the app's directory.

**Rollback.** Revert. `BUILD_CONFIGURATION=debug` restores the old build behavior
without a revert if needed.

**Limitation.** Shortcut assignments are fixed. Deleting local data is not offered.

## Documentation and review focus

Changed: the release-readiness UI-fixes plan, `CONTEXT.md`, the planning board.

Focus on whether **any surface still reaches for `settingsAssetName` where it means
the menu bar**, which would reintroduce the block.
