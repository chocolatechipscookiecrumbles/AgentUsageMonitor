# PR 13 — Rename the product to Agent Monitor and set the version to 0.0.1

**Branch:** `feature/agent-monitor-rename` → `feature/repo-asset-hygiene` · 1 commit, 7 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 9 of 10 — merge after PR 12.
**State: Draft** — the renamed copy has no signed-app acceptance.

**19 lines changed.** It is small and worth reading closely anyway: it decides what
the product is called and where the naming boundary sits.

## Summary

- Renames the product to **Agent Monitor** everywhere a user reads it. It has read
  Claude Code as well as Codex since the Claude provider shipped, so "Codex Usage
  Monitor" named half of what it does.
- Leaves developer naming alone — `CFBundleIdentifier`, `CFBundleName`, the target,
  the source tree, and the Application Support directory.
- Sets `CFBundleShortVersionString` from `1.0.0` (PR 11) to **`0.0.1`**.

## Problem and root cause

**Symptom.** The name described one of two providers. In the menu bar, in Finder, in
a macOS permission prompt, and in the README, the app told users it was a Codex tool.

**Root cause.** The name was correct when Codex was the only provider and was never
revisited when Claude shipped — the same shape of omission as the release surface in
PR 5.

**Second decision: the version.** `1.0.0` was set in PR 11 on the reasoning that the
feature set is complete. That conflates two things. The feature set is complete; the
*distribution* is not — nobody outside this machine has run the app, several
surfaces have no signed-app acceptance, and the Claude credential path is expected
to be replaced. `0.0.1` says that. `1.0.0` is for the build you would defend to a
stranger.

## Scope and non-goals

**Included — every string a user reads:**

| Surface | File |
|---|---|
| Finder, Get Info, notification banners | `Info.plist` `CFBundleDisplayName` |
| The Terminal permission prompt | `Info.plist` `NSAppleEventsUsageDescription` |
| Popover **Quit** command | `MenuActionFooter`, `MenuActionShortcut` |
| Diagnostics **Name** row | `DiagnosticsSettingsView` |
| Diagnostics **Copy Report** title | `SettingsStatus` |
| Exported-data `application.name` | `LocalDataActions` |

**Not included, by decision:** `CFBundleIdentifier`, `CFBundleName`,
`CodexUsageMonitor.app`, the target and directory names,
`~/Library/Application Support/CodexUsageMonitor` and its six file names, the
`CodexUsageMonitor-local-data-<date>.json` export filename, and the repository name.

## Design and ownership

**Why identity does not move.** A new `CFBundleIdentifier` is a *new app* to macOS:
preferences reset to defaults, the Keychain "Always Allow" grant for the Claude
credential is lost, and every first-run prompt returns. Renaming the Application
Support directory strands each existing cache and history file. Both costs land
entirely on existing users, to fix a string no user sees.

**The Quit title is duplicated** across `MenuActionFooter` and `MenuActionShortcut`,
so both needed changing. That duplication is a latent drift bug — the footer can
say one thing while the catalog says another — and is worth collapsing separately.

The download stays `CodexUsageMonitor-0.0.1.zip`, matching the bundle inside it. A
zip named for the product containing a bundle named for the target is more confusing
than either name alone. The README and release notes state the mismatch plainly
rather than letting a user meet it at install time.

## Privacy, compatibility, and migration

**Privacy.** Not applicable — copy only.

**Compatibility.** Preserved deliberately. Because the identifier and data directory
are unchanged, an upgrading user keeps preferences, Keychain grant, quota history,
and token cache.

**Migration.** None required, which is the point of the boundary above.

## Regression proof

**None, and none is possible.** This is copy; there is no old failure to reproduce.

That cuts both ways: the 316-test suite **asserts nothing about any of these
strings**, so a green suite is not evidence that this PR is correct. Only looking at
the running app is.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | Build complete |
| `swift test` at this branch tip | Run | 316 tests, 1 skipped, 0 failures across two clean re-runs — but see above: the suite does not cover this copy. One earlier run showed a single failure matching the documented `testReconnectResumesReading` flake |
| `plutil -p Info.plist` | Run | `CFBundleDisplayName = Agent Monitor`, `CFBundleShortVersionString = 0.0.1`, identifier unchanged |
| `git grep "Codex Usage Monitor" -- CodexUsageMonitor/` | Run | No matches |
| Get Info, popover Quit row, Diagnostics **Name**, Copy Report paste, export file | **Not run** | |
| Terminal permission prompt text | **Not run** | macOS caches it per app; needs a permission reset to re-trigger |

## Risks, rollback, and limitations

**Risk.** A user-visible string was missed, leaving the app half-renamed. The
`git grep` above is the check, and it is only as good as the phrase searched — a
string that says "Codex" without "Usage Monitor" would not appear in it.

**Second risk — the version.** `0.0.1` invalidates the notarization submission in
flight, which was for `1.0.0` / build `254`. `254` is now spent, and Apple rejects a
re-used build number, so publishing needs a rebuild with a fresh `CFBundleVersion`.

**Rollback.** Revert. Copy and a version string; nothing persisted changes.

**Limitations.** The repository is still `agent-usage`, matching neither name. The
remaining rename surfaces are enumerated in
`docs/development/before-going-public.md`.

## Documentation and review focus

Changed: `docs/release-notes/0.0.1.md` (renamed from `1.0.0.md`).

**Focus on the boundary itself.** Is "user-visible strings move, identity does not"
the right split? If it is wrong, it is far cheaper to change now — before a release
exists and before anyone has preferences to lose — than at any later point.
