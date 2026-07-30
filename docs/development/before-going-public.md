# Before going public

This is about **the repository**, not the app release. The release checklist lives
in [releasing-on-github.md](releasing-on-github.md); this file covers what has to
change before `chocolatechipscookiecrumbles/agent-usage` is readable by strangers.

Written 2026-07-29, when the app was signed with a Developer ID identity and its
notarization submission was in flight.

Each item says what it is, **why it matters**, and the fix. Nothing here is done
unless it is marked done.

---

## Blockers — do not make the repository public until these are resolved

### 1. There is no licence

`git ls-files` finds no `LICENSE`. The README says "non-commercial," which states
an *intent* but has no legal effect on its own.

**Why it matters.** With no licence, default copyright applies: all rights reserved.
Nobody may legally copy, modify, or redistribute the source — and strictly, the
`.app` you hand out has no stated terms either. A public repo with no licence reads
as an oversight rather than a decision, and it is the first thing a careful reader
checks.

**The fix — a decision only you can make.** Three realistic options:

| Option | What it gives you | Cost |
|---|---|---|
| **PolyForm Noncommercial 1.0.0** | Says exactly what the README already claims: use, modify, share, but not commercially. Written for software. | Not OSI-approved, so GitHub labels it "non-standard" and some people will skip it |
| **A short proprietary notice** ("personal, non-commercial use only; no redistribution") | Maximum control, minimum ambiguity | Not a recognised licence; no community norms attach |
| **A permissive OSI licence** (MIT / Apache-2.0) | Recognised, frictionless | Contradicts "non-commercial" — you would be allowing commercial use |

Recommended: **PolyForm Noncommercial 1.0.0**, because it matches the claim already
made in the README and the release notes. Add it as `LICENSE`, and change the
README's License section to point at it instead of at this file.

- [ ] Licence chosen and `LICENSE` committed

### 2. The notarized build is not the build being shipped

The README's Install section says releases "are signed with an Apple **Developer
ID** certificate and notarized by Apple." Apple did notarize the app on
2026-07-29 — but that submission was `Codex Usage Monitor` / `1.0.0` / build `254`,
made before the rename and the version change.

**Why it matters.** A notarization ticket binds to the submitted binary's
code-directory hash. Editing `CFBundleDisplayName` and `CFBundleShortVersionString`
changes that hash, so the accepted ticket cannot apply to the shipping bundle. The
approval is easy to mistake for "the app is notarized"; what it establishes is that
the *signing setup* satisfies the notary, which is a different and lesser claim.

**The trap to avoid.** The final verification replaced `.build` with an ad-hoc
`Agent Monitor` / `0.0.1` / `266` candidate. It is not the earlier accepted
Developer ID build and is not a shipping artifact. Rebuild with the Developer ID
identity before you submit or package anything, and do not reuse any surviving
`Codex Usage Monitor` / `1.0.0` archive from the 2026-07-29 run.

**The fix.** `CFBundleVersion` is already `266` in the repository (`254` is
permanently consumed — Apple tracks build numbers per bundle identifier, which the
rename did not change). Rebuild, submit, staple, and confirm `spctl -a -vv` prints
`accepted … source=Notarized Developer ID`. Publish nothing before that. If you end
up shipping Path B instead, rewrite that Install paragraph and add the `xattr`
workaround.

- [x] `CFBundleVersion` bumped to `266`
- [ ] Rebuilt — `plutil` confirms `Agent Monitor` / `0.0.1` / `266` inside the bundle
- [ ] Notary returned `Accepted`, ticket stapled, `spctl` verdict re-checked
- [ ] No superseded `1.0.0` bundle or zip remains, and the release zip was created
      only from the stapled `Agent Monitor` / `0.0.1` / `266` app

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
- [ ] Re-read the app's Data & Privacy page in the signed build and confirm the
      wording still matches

---

## Should fix — these make the repo read as unfinished

### 4. Personal learning scaffolding sits at the repository root

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

**Why it matters.** A visitor's first impression of a repository is its root
listing. Right now that listing mixes an app, its docs, and someone's private
coursework, which makes the serious parts look less serious than they are.

**The fix — cheap, because inbound links are almost nil.** Only
`docs/superpowers/plans/2026-07-24-prototype-finalization.md` links `MISSION.md` and
`RESOURCES.md`; the rest are unreferenced except by each other.

```sh
mkdir -p docs/notes
git mv MISSION.md NOTES.md RESOURCES.md feasibility_assessment.md docs/notes/
git mv learning-records lessons reference docs/notes/
# then fix: the two links in 2026-07-24-prototype-finalization.md, and the
# ../assets/course.css href inside the four moved HTML pages
```

**Do not move `outline.md`, `how-to.md`, `CONTEXT.md`, or `AGENTS.md`.** They are
cross-linked from dozens of plan documents that form the project's evidence trail;
moving them is a much larger, riskier edit and buys much less.

- [ ] Scaffolding relocated or deleted

### 5. Screenshots cannot currently be committed

As of 2026-07-29 the repository ignores every image, so the README has no gallery.
Comparable menu-bar apps lead with one — it is usually the single most persuasive
element on the page.

**Why it matters.** A menu-bar app is almost entirely visual. Describing the popover
in prose is strictly worse than showing it, and a README with no picture reads as
abandoned even when the project is not.

**The fix — pick one:**

- **Un-ignore a screenshots directory** (recommended). Add to `.gitignore`:
  ```
  !docs/screenshots/
  !docs/screenshots/*.png
  ```
  Keep them few and small; they are the one image class worth versioning.
- **Host them outside the repo.** Drag images into a GitHub issue or the release
  body and hot-link the resulting `user-images.githubusercontent.com` URLs. Nothing
  lands in git, but the links rot if the issue is deleted.

- [ ] Screenshot route chosen, and the README updated to use it

### 6. `how-to.md` is not a how-to

It documents the login flow, the usage probe, and running the app from source — an
operating log for you, not a user guide. The README used to describe it as
"user-facing behavior and operations," which was wrong; the rewritten README now
describes it accurately.

**Why it matters.** A public repo with a file called `how-to.md` sets an expectation
it does not meet, and the person who follows it is a *user*, not a maintainer.

**The fix.** Either rename it (`docs/development/operating-notes.md`) or leave the
name and keep the accurate description. If you rename it, update
[AGENTS.md](../../AGENTS.md#documentation-discipline) line 30, which names the file
as a required update target, along with the ~8 plan documents that link it.

- [ ] Decided

### 7. Absolute `<USER_HOME>/…` paths in tracked documents

Fixed on 2026-07-29 in `docs/claude-usage-verification.md`, `how-to.md`, and
`docs/superpowers/plans/2026-07-12-codex-menu-bar-mvp.md` — the last of those had
two markdown links pointing at absolute local paths, which render as **broken links
on GitHub**.

Two remain, inside the course HTML pages (`lessons/0001-…html`,
`reference/codex-monitor-ui-map.html`). They are illustrative shell snippets rather
than links, and both files are candidates for item 4 anyway.

- [x] Markdown documents cleaned
- [ ] HTML pages cleaned, or moved under item 4

### 8. The rename to Agent Monitor — what is done, what is left

**Decided 2026-07-29:** the product is **Agent Monitor**, because it no longer
monitors Codex alone. Documents and every user-visible string were changed;
developer naming was deliberately left alone.

| Surface | State | Notes |
|---|---|---|
| README title and prose | ✅ Agent Monitor | |
| Release notes | ✅ Agent Monitor 0.0.1 | |
| Release guide prose, tag messages, `gh` titles | ✅ Agent Monitor | |
| Planning board record | ✅ | |
| `CFBundleDisplayName` | ✅ Agent Monitor | What Finder, Get Info, and notification banners show |
| `NSAppleEventsUsageDescription` | ✅ "Agent Monitor opens Terminal…" | Read by the user in a macOS permission prompt |
| Popover **Quit** command | ✅ "Quit Agent Monitor" | `MenuActionFooter`, `MenuActionShortcut` — both, since the title is duplicated |
| Diagnostics **Name** row | ✅ Agent Monitor | `DiagnosticsSettingsView` |
| Diagnostics **Copy Report** title | ✅ "Agent Monitor diagnostics" | `SettingsStatus` |
| Exported-data `application.name` | ✅ Agent Monitor | `LocalDataActions` |
| `CodexUsageMonitor.app`, `com.david.codex-usage-monitor`, `CFBundleName`, target and directory names | ⬜ unchanged **by choice** | Developer naming. Changing the identifier orphans existing preferences and Keychain grants |
| `~/Library/Application Support/CodexUsageMonitor` and the six file names | ⬜ unchanged **by choice** | Real paths. Renaming them strands every existing user's cache and history |
| Export filename `CodexUsageMonitor-local-data-<date>.json` | ⬜ | User-visible in the save panel, but named after the data directory it comes from. Rename only if the directory is ever renamed |
| Repository name `agent-usage` | ❌ | Matches neither the old nor the new product name |

**Leave `CFBundleIdentifier` alone regardless.** A new identifier is a new app to
macOS: preferences reset, the Keychain "Always Allow" grant is lost, and the user
gets every first-run prompt again.

**Remaining:**

- [ ] **Signed-app acceptance of the renamed strings** — the source change is
      verified only by `swift build` and the 316-test suite, which assert nothing
      about this copy. Check Finder's Get Info, the popover's Quit row, the
      Diagnostics **Name** row, a **Copy Report** paste, and an **Export Local
      Data…** file. Also re-trigger the Terminal permission prompt if you can, since
      macOS caches its text per app.
- [ ] Repository renamed, or the mismatch accepted (easiest *before* the first
      release is published; GitHub redirects the old URL afterwards)

---

## Worth doing, not urgent

- **Repository description and topics.** Empty right now. Set a one-line description
  and topics like `macos`, `menu-bar`, `swiftui`, `openai-codex`, `claude-code`.
- **Issue templates.** `.github/` contains only `pull_request_template.md`. A bug
  template that asks for macOS version, app version and build, and which provider is
  connected will save several round trips.
- **`SECURITY.md`** — but only if you actually want vulnerability reports. An
  unanswered security policy is worse than none.
- **Contribution stance.** The README states that unsolicited PRs may not be merged.
  Comparable projects put this up front and it works well; consider a one-paragraph
  `CONTRIBUTING.md` saying the same thing so GitHub surfaces it in the PR flow.
- **Affiliation disclaimer in the app**, not just the README — a line in
  **Diagnostics** or an About panel stating no affiliation with OpenAI, Anthropic,
  GitHub, or Apple.
- **Do not describe unverified surfaces as tested.** The planning board's
  **Verification** rows are the live list. Public copy — README, release notes,
  issue replies — should not promote them to "verified."

---

## Already checked and clean

Recorded so it does not have to be re-litigated:

| Check | Result |
|---|---|
| Secrets, API keys, private keys in tracked files | **None.** Every `sk-ant-…` hit is a test fixture or a `REPLACE_ME` placeholder |
| Email addresses | **None** |
| Live probe output | **None tracked** — `UsageProbe/Outputs/` is ignored except its `.gitkeep` |
| Local credentials and quota caches | Ignored: `auth.json`, `last-known-good.json`, `quota-history.json`, `.env*` |
| Per-machine agent config | Ignored: `.claude/`, `.agents/skills/*`, `skills-lock.json`, `.worktrees/` |
| Real name and Apple Team ID (`Project maintainer`, `<APPLE_TEAM_ID>`) | Present in two docs, by choice. Both are embedded in any distributed signature and readable from the shipped `.app`, so this discloses nothing new |
| Build artifacts | Ignored: `.build/`, `DerivedData/`, `__pycache__/`, `*.log` |
