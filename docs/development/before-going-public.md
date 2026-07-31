# Before going public

This is about **the repository**, not the app release. The release checklist lives
in [releasing-on-github.md](releasing-on-github.md); this file covers what has to
change around the **AgentUsageMonitor** project. Its current GitHub endpoint remains
private. Public publication targets a new
`chocolatechipscookiecrumbles/AgentUsageMonitor` repository rather than changing
the visibility of the repository that holds the original review and audit history.

Written 2026-07-29 and updated after the verified 0.0.1 publication on 2026-07-31.
Release-specific signing item 2 is closed; the separate repository-publication
items remain live unless marked done.

The authenticated GitHub portion is performed manually using the
[sanitized-repository publication checklist](manual-publication-checklist.md).

Each item says what it is, **why it matters**, and the fix. Nothing here is done
unless it is marked done.

---

## Blockers — do not make the repository public until these are resolved

### 1. Closed — MIT licence selected

The repository now carries the standard MIT License with
`Copyright (c) 2026 chocolatechipscookiecrumbles`. Public-facing source-licensing
copy in the README and release notes now points to it.

The MIT License covers this project's source and documentation. It does not grant
rights to provider services, credentials, names, marks, or third-party terms.
Historical personal-use statements that document the accepted Claude
provider-policy risk are retained because they are not source-licensing terms.

- [x] Licence chosen and `LICENSE` added

### 2. Closed — notarize the actual shipping build

Apple first notarized `Codex Usage Monitor` / `1.0.0` / build `254` on 2026-07-29,
before the rename and version change. That historical ticket could not cover the
shipping artifact. `Agent Monitor` / `0.0.1` / build `266` was subsequently signed,
notarized, stapled, published, downloaded, and verified on 2026-07-31.

**Why it matters.** A notarization ticket binds to the submitted binary's
code-directory hash. Editing `CFBundleDisplayName` and `CFBundleShortVersionString`
changes that hash, so the accepted ticket cannot apply to the shipping bundle. The
approval is easy to mistake for "the app is notarized"; what it establishes is that
the *signing setup* satisfies the notary, which is a different and lesser claim.

**The trap that was avoided.** The release-readiness verification had replaced
`.build` with an ad-hoc `Agent Monitor` / `0.0.1` / `266` candidate. It was not a
shipping artifact, and the surviving `Codex Usage Monitor` / `1.0.0` archive from
the 2026-07-29 run could not be reused.

**The completed fix.** Build `266` was rebuilt with the Developer ID identity,
submitted, accepted, stapled, packaged, published, and downloaded again for
verification on 2026-07-31. Build `254` remains permanently consumed because Apple
tracks build numbers per bundle identifier.

- [x] `CFBundleVersion` bumped to `266`
- [x] Rebuilt — `plutil` confirmed `Agent Monitor` / `0.0.1` / `266` inside the bundle
- [x] Notary returned `Accepted`, ticket was stapled, and the release artifact was
      downloaded and verified after publication on 2026-07-31
- [x] The published release zip was created only from the stapled
      `Agent Monitor` / `0.0.1` / `266` app

### 3. The Claude ToS disclosure is load-bearing — keep it in all three places

The 2026-07-29 decision was to publish *with* the caveat disclosed: in the README,
in the app's **Data & Privacy** page, and in the release notes.

**Why it matters.** Making the repository public raises the visibility of a build
that knowingly reuses another product's credential contrary to its terms. The
disclosure is the entire basis on which that was judged acceptable. Removing or
softening it in any one of the three places — including "tightening up" the README
for a public audience — invalidates the decision.

- [x] Present in the README (prominent, above the fold)
- [x] Present in [release notes 0.0.1](../release-notes/0.0.1.md)
- [x] Re-read the signed 0.0.1 Data & Privacy page on 2026-07-31; its wording is
      unchanged and still matches the README and release notes

---

## Should fix — these make the repo read as unfinished

### 4. Closed by decision — retain the study notes, but sanitize them

These are study notes from building the project, not project documentation:

| Path | What it is |
|---|---|
| `MISSION.md` | "Become a stronger macOS developer by studying neighboring projects" |
| `NOTES.md` | Teaching notes about how to run the sessions |
| `RESOURCES.md` | A personal reading list |
| `feasibility_assessment.md` | The July 12 go/no-go write-up |
| `learning-records/` | One dated learning record |
| `lessons/*.html` | Two rendered course pages |
| `reference/*.html` | Two rendered reference pages |

The maintainer chose to keep these notes in their current locations as part of the
project's learning and decision record. Names, institutional addresses, signing
team identifiers, and user-specific filesystem paths must not appear in them or in
the rest of the public source tree.

- [x] Keep the study notes in place
- [x] Replace current-tree personal identifiers and user-home paths with neutral
      placeholders or repository-relative commands
- [ ] Re-run the same checks against rewritten full history before publication

### 5. Screenshots deferred

As of 2026-07-29 the repository ignores every image, so the README has no gallery.
Comparable menu-bar apps lead with one — it is usually the single most persuasive
element on the page.

**Why it matters.** A menu-bar app is almost entirely visual. Describing the popover
in prose is strictly worse than showing it, and a README with no picture reads as
abandoned even when the project is not.

The maintainer has deferred screenshots until approved, redistributable assets
exist. Do not un-ignore local design or release assets merely to fill this gap.

- [x] Screenshot work explicitly deferred

### 6. Closed — operating notes renamed

It documents the login flow, the usage probe, and running the app from source — an
operating log for you, not a user guide. The README used to describe it as
"user-facing behavior and operations," which was wrong; the rewritten README now
describes it accurately.

**Why it matters.** The old filename implied a user guide. The new path and heading
correctly present the document as maintainer-facing operational context.

The file is now `docs/development/operating-notes.md`, with no redirect stub. Its
heading, README description, repository rules, plan references, and links identify
it as maintainer operating notes.

- [x] Renamed and current references updated

### 7. Closed — user-specific absolute paths removed

Fixed on 2026-07-29 in `docs/claude-usage-verification.md`, `docs/development/operating-notes.md`, and
`docs/superpowers/plans/2026-07-12-codex-menu-bar-mvp.md` — the last of those had
two markdown links pointing at absolute local paths, which render as **broken links
on GitHub**.

- [x] Markdown documents cleaned
- [x] HTML examples use repository-relative commands

### 8. Public naming layers — what is done, what is left

**Decided 2026-07-29:** the shipped app display name is **Agent Monitor**, because
it no longer monitors Codex alone. **Updated 2026-07-31:** the project and local
clone name are **AgentUsageMonitor**. The GitHub repository name/slug remains
private in the original repository; the sanitized public candidate will use a new
`AgentUsageMonitor` repository. Developer naming was deliberately left alone.

| Surface | State | Notes |
|---|---|---|
| README title | ✅ AgentUsageMonitor | Project name |
| README app-facing prose | ✅ Agent Monitor | Shipped app display name |
| Release notes | ✅ Agent Monitor 0.0.1 | |
| Release guide prose, tag messages, `gh` titles | ✅ Agent Monitor | |
| Planning board record | ✅ | |
| `CFBundleDisplayName` | ✅ Agent Monitor | What Finder, Get Info, and notification banners show |
| `NSAppleEventsUsageDescription` | ✅ "Agent Monitor opens Terminal…" | Read by the user in a macOS permission prompt |
| Popover **Quit** command | ✅ "Quit Agent Monitor" | `MenuActionFooter`, `MenuActionShortcut` — both, since the title is duplicated |
| Diagnostics **Name** row | ✅ Agent Monitor | `DiagnosticsSettingsView` |
| Diagnostics **Copy Report** title | ✅ "Agent Monitor diagnostics" | `SettingsStatus` |
| Exported-data `application.name` | ✅ Agent Monitor | `LocalDataActions` |
| Published disk image / contained app | ✅ `AgentUsageMonitor-0.0.1.dmg` / `AgentUsageMonitor.app` | Observed release names |
| Build output `.build/CodexUsageMonitor.app`, `com.david.codex-usage-monitor`, `CFBundleName`, target and directory names | ⬜ unchanged **by choice** | Internal compatibility naming. Changing the identifier orphans existing preferences and Keychain grants |
| `~/Library/Application Support/CodexUsageMonitor` and the six file names | ⬜ unchanged **by choice** | Real paths. Renaming them strands every existing user's cache and history |
| Export filename `CodexUsageMonitor-local-data-<date>.json` | ⬜ | User-visible in the save panel, but named after the data directory it comes from. Rename only if the directory is ever renamed |
| Project/local clone name | ✅ AgentUsageMonitor | README and clone destination |
| Public GitHub repository name/slug and endpoint | ⏳ `AgentUsageMonitor` | Create a separate private repository after history rewrite; do not change the original repository's visibility |

**Leave `CFBundleIdentifier` alone regardless.** A new identifier is a new app to
macOS: preferences reset, the Keychain "Always Allow" grant is lost, and the user
gets every first-run prompt again.

**Post-release state:**

- [x] The published signed app was downloaded, launched, and observed working as
      intended on 2026-07-31.
- [ ] An exhaustive renamed-string sweep remains useful: Finder Get Info, the Quit
      row, Diagnostics Name, copied report, exported data, and a newly triggered
      Terminal permission prompt. The release smoke test does not prove every
      cached or permission-dependent string.
- [ ] Create the new private `AgentUsageMonitor` destination after history rewrite,
      push only rewritten `main` and `v0.0.1`, and keep the original repository
      private indefinitely.

---

## Worth doing, not urgent

- **Repository description and topics.** Configure the new repository with the
  approved description and `macos`, `menu-bar`, `swift`, `swiftui`,
  `openai-codex`, `claude-code`, and `usage-monitor`.
- **Issue templates.** Done in source: the privacy-safe bug form asks for version,
  build, macOS, provider, surface, reproduction, and expected/actual behavior;
  blank issues are disabled.
- **`SECURITY.md`.** Done in source: vulnerability reports go through GitHub's
  private vulnerability reporting, with no fixed response SLA.
- **Contribution stance.** Done in source: issues are welcome, implementation PRs
  require prior agreement, and privacy-sensitive records must never be attached.
- **Affiliation disclaimer in the app.** Planned, not implemented. The dedicated
  [Diagnostics disclaimer plan](../superpowers/plans/2026-07-31-diagnostics-affiliation-disclaimer.md)
  carries the exact copy, Settings skills, signed-app Light/Dark and Context Rail
  matrix, wrapping, and VoiceOver acceptance.
- **Do not describe unverified surfaces as tested.** The planning board's
  **Verification** rows are the live list. Public copy — README, release notes,
  issue replies — should not promote them to "verified."

---

## Current-tree preliminary checks

These current-tree observations do not replace the required two-scanner,
full-history audit:

| Check | Result |
|---|---|
| Secrets, API keys, private keys in tracked files | **None.** Every `sk-ant-…` hit is a test fixture or a `REPLACE_ME` placeholder |
| Email addresses | **None** |
| Live probe output | **None tracked** — `UsageProbe/Outputs/` is ignored except its `.gitkeep` |
| Local credentials and quota caches | Ignored: `auth.json`, `last-known-good.json`, `quota-history.json`, `.env*` |
| Per-machine agent config | Ignored: `.claude/`, `.agents/skills/*`, `skills-lock.json`, `.worktrees/` |
| Personal legal name and Apple Team ID in source/docs | Replaced with neutral placeholders. The already signed release remains exempt because Developer ID signatures inherently expose the certificate holder |
| Build artifacts | Ignored: `.build/`, `DerivedData/`, `__pycache__/`, `*.log` |
