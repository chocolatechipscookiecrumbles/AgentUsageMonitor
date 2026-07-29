# PR 5 — Release readiness: Token Monitor, native bridge, and the Agent Monitor rename

**Branch:** `feature/release-readiness` → `main` · 36 commits, 108 files
**Compare:** historical private-repository comparison (branch not published)
**State: Draft.** The release it prepares is not finished — the signed bundle
predates the version change and no notarization ticket is stapled. Several
surfaces have no signed-app acceptance. See [Verification](#verification).

## Summary

- Ships the **Token Monitor**: tokens observed from Codex's and Claude Code's own
  local record files, per provider, by day or by calendar week, rendered in the
  popover and configurable per agent. Independent of quota, nothing uploaded, no
  tokens spent to produce it.
- Makes the app **distributable**: a native Swift replacement for the Python
  Claude bridge, an optimized release binary, a full app icon set, and a written
  release procedure. The app is now signed with a real Developer ID identity.
- **Renames the product to Agent Monitor** and sets the version to `0.0.1`, since
  it no longer monitors Codex alone.
- **Deliberately deferred:** the popover outgrows a small screen at the Token
  Monitor's tallest state, and no fix is claimed. The rebuild and re-notarization
  that this release actually needs are not in this PR.

## Problem and root cause

Three separate problems, addressed in sequence on one branch.

**1. Quota was the only thing the app could show.** Provider quota answers "how
much is left," but not "what have I actually been spending it on." Both Codex and
Claude Code already write per-request records locally, so the information existed
on disk with no reader.

*Cause:* no domain model for a request, no reconciliation for either provider's
record shape, and no surface to render one. Codex writes cumulative totals with
forks; Claude Code writes streaming records with sidechains. Neither can be summed
naively — Codex double-counts across a fork, Claude duplicates across a sidechain.

**2. The app could not be handed to anyone.** It required `python3` for the Claude
bridge, built a debug binary, had no icon, and had never been signed or notarized.

*Cause:* nothing here was a defect. The app had only ever been run from source on
one machine, so none of the distribution surface existed yet.

**3. The name stopped being true.** "Codex Usage Monitor" was accurate when Codex
was the only provider. With Claude Code shipped, the name describes half the
product — in the menu bar, in Finder, in a macOS permission prompt, and in the
README.

## Scope and non-goals

**Included:**

- Token activity domain, per-provider reconciliation, incremental file-event
  scanning, and a cache that survives relaunch (`Activity/`).
- The popover's Token Monitor card, in both provider tabs
  (`Menu/ProviderTokenActivityCard.swift`).
- Per-agent Token Monitor settings: section visibility, collection gating with
  cache purge, and a Day/Week range (`Settings/AgentTokenMonitorSection.swift`,
  `Settings/TokenMonitorRange.swift`).
- `ClaudeUsageBridge` / `ClaudeUsageBridgeCore` as native Swift targets, bundled
  and signed inside the app.
- Release binary (`-c release`), `AppIcon.appiconset` at all ten sizes, and the
  `.icns` built by `iconutil`.
- Popover fixes: footer command shortcuts, a template-safe Codex menu-bar glyph,
  provider-tab hit areas, tab-strip height, and a plan name in the header.
- Data & Privacy and Diagnostics actions (reveal, copy path, export, copy report,
  clear history).
- The product rename to **Agent Monitor** across every user-visible string, and
  `CFBundleShortVersionString` `1.0.0` → `0.0.1`.
- Documentation: rewritten README, the release guide, `before-going-public.md`,
  and planning-board reconciliation.
- Assets removed from version control.

**Not included:**

- **The popover height fix.** Deferred by direction on 2026-07-28. Candidate
  approaches are recorded on the Bug-fix board; none is chosen.
- **Rebuild and re-notarization at `0.0.1`.** Waiting on the current notary
  result first, by direction.
- **The identifier rename.** `com.david.codex-usage-monitor`, `CFBundleName`, the
  target, the source tree, and the Application Support directory are unchanged.
- **Editable keyboard shortcuts.** The four assignments are fixed and the
  Settings page says so.
- **GitHub Copilot.** Still absent behind its capability gate.
- **A licence.** No `LICENSE` file is chosen yet; this blocks making the
  repository public, not this merge.

## Design and ownership

**Token activity.** `LocalActivityModels` defines the request domain. Each provider
gets its own reconciler, because the failure modes differ: Codex records cumulative
totals that must be differenced across forks, Claude Code streams records whose
sidechains repeat a request. Both normalize to the same request identity, which is
**hashed** — no file path, session identifier, or record content enters the model.
`LocalActivityCache` persists only the reconciled values the card already shows, so
a relaunch renders before re-reading anything. Scanning is incremental on file
events, not polled.

The Day/Week range steps bucket edges **through the calendar**, not by a fixed
number of seconds, so a daylight-saving day stays exactly one bar. Both ranges read
the same reconciled request set, so switching cannot report a figure the current
scan did not observe.

**Claude bridge.** `ClaudeUsageBridgeCore` holds the pure decode-and-write logic so
it is directly testable; `ClaudeUsageBridge` is the executable. The app copies it to
app-owned Application Support before use. Signing is inside-out — the nested helper
first, the app last — because notarization rejects an unsigned nested Mach-O.

**Naming.** User-visible strings changed; identity did not. A new
`CFBundleIdentifier` is a new app to macOS: preferences reset, the Keychain "Always
Allow" grant is lost, and every first-run prompt returns. The same reasoning keeps
`~/Library/Application Support/CodexUsageMonitor` and its six file names, which
would otherwise strand existing caches and history.

## Privacy, compatibility, and migration

**Privacy.** The Token Monitor reads local record files that already exist on the
machine. Only hashed request identities, timestamps, model names, and token counts
enter the model — no prompt, response, file path, or session identifier. Nothing is
uploaded; producing the view spends no tokens. The bridge change **removes** a
runtime dependency rather than adding one.

**The standing caveat is unchanged and must stay disclosed.** Claude usage is read
from the OAuth credential Claude Code stored in the user's Keychain. Anthropic's
Terms of Service do not permit a third-party application to do that. The 2026-07-29
decision was to publish anyway, with the caveat stated in the README, the app's
Data & Privacy page, and the release notes. Do not remove it from any of the three
while this path ships.

**Compatibility.** Both providers' record formats are externally controlled and can
change without notice; reconciliation is fixture-tested against the shapes observed
to date. macOS 14+ unchanged.

**Migration.** The activity cache is new and absent-safe. Its retention grew from
three days to fourteen so a relaunch can still fill a week view. Per-agent Token
Monitor preferences default to enabled with a Day range, so an upgrade shows the
card without configuration. An unknown stored range falls back to Day
(`testUnknownStoredRangeFallsBackToDay`). No existing persisted schema is rewritten,
and a rollback ignores the new keys.

## Regression proof

Per the repository's testing policy, automated coverage was added only for
reproducible defects, not for feature presence.

- **Codex fork double-counting and Claude sidechain duplication** — reconciliation
  fixtures cover cumulative-versus-delta totals, unique sidechain preservation, and
  evidence validation. These recreate the over-count that naive summing produced.
- **`MenuBarProviderGlyphTests`** — the Codex menu-bar glyph rendered as a solid
  block because the menu bar named `settingsAssetName`, whose Codex artwork is
  full-bleed opaque (measured 97% opaque at 64pt) and was being templated. The test
  **fails against the old asset and passes against the new** `CodexMenuBar`
  imageset.
- **Per-provider activity cache writes** — a single shared write path let one
  provider's scan clobber the other's cached requests.
- **`testUnknownStoredRangeFallsBackToDay`** — an unrecognized persisted range must
  not leave the card blank.

The rename and version change have **no regression test and need none** — they are
copy. That also means the test suite proves nothing about them; see below.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` | Run | Build complete, 0 errors |
| `swift test` | Run | **316 tests, 0 failures** (2026-07-29 21:04) |
| `codesign -dvv` on the built `.app` | Run | `Authority=Developer ID Application: Project maintainer (<APPLE_TEAM_ID>)`, `flags=0x10000(runtime)`, `Timestamp=Jul 29, 2026 at 18:09:56` |
| `codesign -d --entitlements -` | Run | None — no `get-task-allow` |
| `spctl -a -vv` | Run | `rejected … source=Unnotarized Developer ID` — the expected pre-ticket verdict |
| `xcrun stapler validate` | Run | "does not have a ticket stapled to it" |
| Notarization | **Not run** | Submitted for the superseded `1.0.0`/`254` build; result outstanding. Nothing may be tagged or published until a `0.0.1` build is notarized with a fresh `CFBundleVersion` |
| Token Monitor against live records | Observed | Both providers reconcile; card renders in both tabs |
| Provider-tab switching and hit areas | Observed | Enlarged targets confirmed in the signed app |
| Settings destinations, widths, switches, VoiceOver, appearance segments | Observed | Inspected in the signed app |
| Popover Token Monitor — visual, keyboard, VoiceOver | **Not run** | Blocked by the deferred height problem; recorded unobserved rather than inferred |
| Renamed strings in the signed app | **Not run** | Get Info, Quit row, Diagnostics **Name**, Copy Report paste, export file, Apple Events prompt. `swift test` asserts nothing about this copy |
| Popover shortcuts firing; each bound only while enabled | **Not run** | Source-verified only |
| Data & Privacy save panel and cleared empty states | **Not run** | Source-verified only |
| Day/Week ranges in Light and Dark; VoiceOver on range-dependent labels | **Not run** | |
| Popover header plan name against a live Codex account | **Not run** | Only the Claude header has been seen |
| Codex menu-bar glyph in Light and Dark menu bars | **Not run** | Regression test passes; visual acceptance outstanding |
| Link check across every edited document | Run | All relative links resolve |

One known flake: `ClaudeUsageMonitorTests.testReconnectResumesReading` failed twice
in roughly 25 runs — it spins on a bounded `Task.yield()` count. Re-run before
concluding anything is broken.

## Risks, rollback, and limitations

**Risk — the most credible one.** Both providers' local record formats are
externally controlled. A format change silently degrades the Token Monitor to
under- or over-counting rather than failing loudly. The card is independent of
quota, so a wrong token figure cannot corrupt the quota reading, but it can mislead.

**Second risk.** The assets change means a fresh clone cannot run
`Scripts/build-app.sh` — `actool` has no catalog to compile. `swift build` is
unaffected. This is a deliberate trade recorded in `.gitignore` and on the board.

**Rollback.** Revert the PR. The activity cache and per-agent preferences are new
optional keys that an older build ignores; no existing persisted schema is
rewritten. The version and rename are copy and revert cleanly. Reverting does
**not** restore the untracked asset files to git — recovering those means reverting
commit `ed38a7e` specifically.

**Known limitations:**

- The popover's tallest state (~915pt on the Codex tab) clips below roughly 775
  usable points at 1280×800. It does not scroll, by design. Per-agent section
  toggles are a workaround, not a fix.
- Claude's weekly window is shared with Claude chat, not Claude Code alone.
- Keyboard shortcuts are not editable.
- GitHub Copilot is absent, not broken.
- The repository is not yet fit to be public: no licence, personal coursework at
  the root, and screenshots now uncommittable. Tracked in
  `docs/development/before-going-public.md`.

## Documentation and review focus

**Changed:** `README.md` (rewritten), `docs/development/releasing-on-github.md`,
`docs/development/before-going-public.md` (new), `docs/product/planning-board.md`,
`docs/release-notes/0.0.1.md` (renamed from `1.0.0.md`),
`docs/adr/0001-read-local-token-activity-automatically.md`, the Token Monitor and
release-readiness plans, `CONTEXT.md`, `how-to.md`, and `.gitignore`.

**Please focus on two things.**

1. **The reconciliation boundary** in `Activity/` — specifically whether a Codex
   fork or a Claude sidechain can still be counted twice under a record shape the
   fixtures do not cover. That is the one place a wrong answer looks plausible.
2. **The scope of the rename.** User-visible strings changed; `CFBundleIdentifier`,
   `CFBundleName`, and the Application Support directory did not. If that split is
   wrong, it is much cheaper to fix before a release exists than after.
