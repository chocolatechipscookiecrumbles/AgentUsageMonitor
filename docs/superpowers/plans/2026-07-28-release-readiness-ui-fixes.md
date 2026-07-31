# Release-Readiness UI Fixes Implementation Plan

> **Status (2026-07-31): Released in 0.0.1.** The published artifact was downloaded
> and observed working as intended. The original exhaustive visual/accessibility
> matrix remains recorded separately where individual states were not explicitly
> exercised.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close three release blockers a user can see. The popover's four footer commands advertise no key equivalents even though the app has an **Enable keyboard shortcuts** preference. The Codex menu-bar glyph renders as a solid block. Data & Privacy and Diagnostics are two full pages of read-only text with nothing to do on them.

**Architecture:** All three are presentation-layer changes. The shortcut catalog is one value type that supplies both the displayed string and the registered key equivalent, so the two can never drift. The glyph fix is an asset-catalog addition plus a new `AgentProvider` accessor, keeping the colored settings artwork and the monochrome menu-bar artwork as separate named assets. The Settings actions are one shared local-data action helper plus per-page buttons; the only new model surface is a `clear()` on `RefreshDiagnosticsStore` reached through `QuotaMonitor`.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (`NSWorkspace`, `NSPasteboard`, `NSSavePanel`), CoreGraphics (test only). No new dependency, no new persistence file, no network call.

## Global Constraints

- **Displayed shortcut and registered shortcut come from one value.** A row must never print `⌘R` while registering something else, and a listed shortcut in Settings must never disagree with the popover. One catalog type owns the character, the modifiers, and the display string.
- **The preference gates registration, not only display.** With **Enable keyboard shortcuts** off, no key equivalent is registered at all — matching what `RefreshNowButton` already does. Turning the toggle off must not leave a live hidden shortcut.
- Key equivalents render in canonical macOS modifier order (`⇧⌘N`, not `⌘⇧N`), because that is what every other Mac menu shows.
- **The shortcut list in Settings is read-only for this change.** Editing is deliberately deferred; the page must say so rather than implying the values are editable.
- Preserve the 340-point, non-scrolling popover and its provider-intrinsic height. The footer rows keep their fixed 34-point height and `MenuPopoverTheme` metrics; a trailing shortcut label adds a column, never a row or a point of height. The deferred *Token Monitor card makes the popover taller than a laptop screen* item must not get worse.
- **A menu-bar glyph must be template-safe.** `MenuBarLabelView` applies `.renderingMode(.template)`, which paints every non-transparent pixel with the tint. Artwork whose interior is opaque therefore renders as a solid block. Menu-bar artwork keeps its knockouts transparent; colored settings artwork stays on its own asset name and is not touched.
- Do not change the colored `Codex`, `Claude`, or `Copilot` imagesets, `AgentSettingsIcon`, or `ProviderIconTile`. The settings tiles and agent pages must look exactly as they do today.
- Destructive and outward-facing actions need a confirmation and honest copy. **Clear History** is confirmed before it runs. **Export** writes only where the user picks in a save panel. No deletion control is added to Data & Privacy in this change; that stays deferred and the page keeps saying so.
- An export must not widen the privacy boundary. It contains exactly the app-owned files already named in `LocalDataInventory` plus the app version — never the Claude Keychain item, never Claude Code's own statusLine source, never anything the app does not already store.
- Build preference rows with `SettingsPage`, `SettingsSection`, `SettingsSectionRow`, `SettingsLabeledRow`, `SettingsValueRow`, and `SettingsDescription`. Do not add a `Form`, a `LabeledContent` outside `SettingsLabeledRow`, or padding that duplicates `SettingsLayoutMetrics`. Rows whose trailing side is text use `SettingsValueRow` so a long value wraps instead of widening the card.
- Do not add feature-presence, routing, happy-path, or implementation-detail tests. The Codex glyph defect is reproducible and gets the smallest deterministic regression test; the other two tasks record a manual regression boundary instead.
- Production Swift changes require `swift build`, the full existing suite, and the signed `.app` from `CodexUsageMonitor/Scripts/build-app.sh`. Settings changes additionally require the AGENTS.md visual acceptance at the default 680 × 560 size with the Context Rail hidden and visible, in Light and Dark.
- Update `docs/product/planning-board.md`, `how-to.md`, and `CONTEXT.md` when behavior, scope, or a limitation changes.

---

## The Codex menu-bar glyph defect

**Symptom.** With the **5-hour and weekly** menu-bar style and Codex selected, the menu bar shows a filled black square in front of `5H: — | Week: 57%`. The General page's **Menu Bar Preview** card shows the same block, filled white against the dark card.

**Cause, measured.** `MenuBarLabelView` draws `Image(providerAssetName)` with `.renderingMode(.template)`. `providerAssetName` resolves through `AgentProvider.settingsAssetName` to the `Codex` imageset, whose artwork is `codex-color.pdf`. Rendering that PDF into a cleared ARGB context and reading the alpha channel shows **every pixel of the 12 × 12 artboard is opaque** — it is a blue mark on an opaque white square, not a transparent glyph. Template rendering replaces all of it with the tint, so a full square is the correct output for the wrong input.

The same probe on the other two menu-bar glyphs shows correctly transparent surrounds and interiors, which is why only Codex is affected:

| Artwork | Alpha coverage rasterized at 64 pt | Template result |
| --- | --- | --- |
| `codex-color.pdf` (current) | 97 % — a full square, short of 100 % only by its antialiased rounded corners | solid block — the defect |
| `codex new menubar fix.pdf` (supplied) | blob outline, `>_` knocked out | correct monochrome mark |
| `claudecode-color.pdf` | transparent surround and interior | correct |
| `githubcopilot.pdf` | transparent surround and interior | correct |

The supplied `assets/icons for agents/codex new menubar fix.pdf` is exactly the needed artwork, so no new icon has to be requested.

**Boundary.** The colored `Codex` imageset stays as it is and keeps serving `AgentSettingsIcon` and `ProviderIconTile`, where an opaque square is deliberate — `ProviderIconTile` documents that Codex fills its tile because the mark carries its own background. Only the menu-bar path moves to the new asset.

---

## File Structure

### New files

```
CodexUsageMonitor/Resources/Assets.xcassets/CodexMenuBar.imageset/Contents.json
CodexUsageMonitor/Resources/Assets.xcassets/CodexMenuBar.imageset/codex-menubar.pdf
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuActionShortcut.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/LocalDataActions.swift
CodexUsageMonitor/Tests/CodexUsageMonitorTests/MenuBarProviderGlyphTests.swift
```

### Modified files

```
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuActionRow.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuActionFooter.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarLabelPresentation.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/QuotaMonitor.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Monitoring/RefreshDiagnosticsStore.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentProvider.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/GeneralSettingsView.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DataPrivacySettingsView.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/DiagnosticsSettingsView.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsDetailView.swift
CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsStatus.swift
```

---

## Task 1 — Key equivalents for the popover footer commands

**Chosen assignments** (decided 2026-07-28):

| Command | Key equivalent | Displayed |
| --- | --- | --- |
| Refresh Now | `r` + ⌘ | `⌘R` |
| Notification Settings | `n` + ⇧⌘ | `⇧⌘N` |
| Preferences… | `,` + ⌘ | `⌘,` |
| Quit Codex Usage Monitor | `q` + ⌘ | `⌘Q` |

`⌘,` and `⌘Q` are the macOS standards. Notification Settings takes `⇧⌘N` rather than plain `⌘N` so the unshifted "new" slot stays unclaimed.

- [x] **Step 1.** Add `MenuActionShortcut` — a `CaseIterable` catalog carrying, per command, the display title, the `KeyEquivalent` character, the `EventModifiers`, and the rendered symbol string in canonical macOS order. This is the single source both the popover row and the Settings list read.
- [x] **Step 2.** Give `MenuActionRow` an optional `shortcut`. When present, render its symbol string right-aligned after the existing `Spacer`, in the theme's secondary text color and at the same disabled opacity as the title, and attach `.keyboardShortcut(_:modifiers:)` to the button. When absent, the row is byte-for-byte what it is today and registers nothing.
- [x] **Step 3.** Have `MenuActionFooter` observe `AppSettings` and pass each row its shortcut only while `keyboardShortcutsEnabled` is true. Update `MenuBarPopoverView` to supply the settings object.
- [x] **Step 4.** In `GeneralSettingsView`'s **Startup & Shortcuts** section, list the four commands and their key equivalents beneath the toggle while it is on, using `SettingsValueRow` so a long command title wraps rather than widening the card. Close the section with a `SettingsDescription` stating the shortcuts are fixed for now. Restate the toggle's own description in terms of what it does now that the list exists.
- [x] **Step 5.** Confirm the footer row height and the popover width are unchanged, and that the tallest Codex tab measurement recorded for the deferred height item still holds.

**Regression boundary (manual).** Toggle **Enable keyboard shortcuts** off and confirm the four symbols disappear from the popover *and* that pressing each combination with the popover open does nothing. Toggle it on and confirm each of the four fires its command. Confirm `⌘R` is inert while a refresh is already running, because that row is disabled.

## Task 2 — Template-safe Codex menu-bar glyph

- [x] **Step 1.** Add a `CodexMenuBar` imageset containing the supplied fix artwork as `codex-menubar.pdf`, preserving its vector representation and declaring a template rendering intent.
- [x] **Step 2.** Add `AgentProvider.menuBarAssetName`, returning the new asset for Codex and the existing names for Claude and Copilot, and document why the menu bar needs a name of its own.
- [x] **Step 3.** Point `MenuBarLabelPresentation.providerAssetName` at `menuBarAssetName`. Leave `settingsAssetName`, `AgentSettingsIcon`, and `ProviderIconTile` untouched.
- [x] **Step 4.** Add `MenuBarProviderGlyphTests`: for every provider, resolve the menu-bar imageset from the repository asset catalog, render its PDF into a cleared ARGB context, and assert the artwork is not fully opaque and has at least one transparent pixel strictly inside its opaque bounding box. Against `codex-color.pdf` this fails on both counts; against the fix it passes.
- [x] **Step 5.** Rebuild the signed `.app` so `actool` compiles the new imageset, and confirm the menu bar and the General **Menu Bar Preview** card both show the Codex mark rather than a block.

**Regression boundary (manual).** Check the glyph in Light and Dark menu bars, and confirm the Agents tab strip, the Agents context rail, the Claude onboarding card, and the popover provider tiles still show the colored marks.

## Task 3 — Real actions on Data & Privacy and Diagnostics

**Scope decided 2026-07-28:** Data & Privacy gets reveal, copy-path, and export. **Deletion stays deferred** and the page keeps saying so. Diagnostics gets copy-report, reveal-file, and clear-history.

- [x] **Step 1.** Add `LocalDataActions`: the resolved Application Support directory URL, reveal-in-Finder, copy-path-to-pasteboard, and a snapshot builder that assembles the app-owned files named in `LocalDataInventory` into one JSON document alongside the app version and export time. A file that is missing or unreadable is recorded as such rather than omitted silently, so an export never overstates what was captured.
- [x] **Step 2.** In **Local storage**, add a final row with **Reveal in Finder** and **Copy Path**.
- [x] **Step 3.** Add an **Export** section presenting **Export Local Data…** through an `NSSavePanel`, stating what the file contains, that it leaves the app's protected folder once written, and that deletion controls remain deferred. Remove the now-stale "Export and deletion controls are intentionally deferred" line from **Excluded data**.
- [x] **Step 4.** Add `RefreshDiagnosticsStore.clear()`, a `QuotaMonitor.clearDiagnostics()` that clears the file and publishes an empty summary, and a `QuotaViewModel` passthrough.
- [x] **Step 5.** Add `SettingsStatus.diagnosticsReport` — a plain-text rendering of exactly what the page shows, so a copied report cannot disagree with the visible page.
- [x] **Step 6.** Add a Diagnostics **Actions** section with **Copy Report** (with a transient copied confirmation), **Reveal Diagnostics File**, and **Clear History…** behind a confirmation dialog naming what is removed. Route the clear closure through `SettingsDetailView`.
- [x] **Release-readiness hardening (2026-07-30).** Open the app-owned directory
  and each allowlisted inventory file descriptor-relatively with `O_NOFOLLOW`,
  require a regular file, and read through the validated descriptor. A planted
  inventory-name symlink is marked unsafe and cannot export a readable JSON target
  outside Application Support.

**Regression boundary.** A narrow automated regression proves an inventory-name
symlink is rejected without exporting its target. Manual acceptance still covers
the save panel, a normal export, reveal/copy, report copy, clear confirmation, and
the next refresh repopulating diagnostics.

---

## Verification

- [x] `swift build --package-path CodexUsageMonitor` exits 0 with no new warnings.
- [x] `swift test --package-path CodexUsageMonitor` — full suite green, including the new glyph regression.
- [x] `CODESIGN_IDENTITY=- zsh CodexUsageMonitor/Scripts/build-app.sh` succeeds and compiles the new imageset.
- [x] `git diff --check` clean.
- [x] Published `v0.0.1` artifact downloaded and observed working as intended on
      2026-07-31.
- [ ] Signed-app visual acceptance per AGENTS.md: General, Data & Privacy, and Diagnostics at 680 × 560 with the Context Rail hidden and visible, Light and Dark; the popover footer with shortcuts on and off; the menu-bar glyph in both appearances.

**Recorded boundary.** The published-artifact smoke test closes the release gate,
but it does not identify every Light/Dark, keyboard, VoiceOver, conditional-state,
or control-specific check in the exhaustive matrix. Do not convert unrecorded
individual states into observed evidence.

## Results — 2026-07-28

**Automated.** `swift build` clean with no new warnings. `swift test` 300 tests, 0 failures — with one pre-existing flake noted below. `CODESIGN_IDENTITY=- zsh CodexUsageMonitor/Scripts/build-app.sh` succeeded; `assetutil --info` on the compiled `Assets.car` confirms `CodexMenuBar` is present with `"Template Mode" : "template"`, and the three colored imagesets are unchanged at `"automatic"`. `git diff --check` clean.

**Pre-existing flake, not introduced here.** `ClaudeUsageMonitorTests.testReconnectResumesReading` failed twice across roughly 25 suite runs and passed every other time. It waits for an async collector by spinning at most 500 `Task.yield()`s, so it is a timing bound inside that test rather than a behavior change: it exercises `ClaudeUsageMonitor`, which this branch does not touch, and it does not reach `QuotaViewModel`, `QuotaMonitor`, or `RefreshDiagnosticsStore`. Ten runs on the stashed clean tree did not reproduce it, which is too few to clear the baseline at that rate. Left unmodified — tightening it is separate work. Do not read a green suite here as proof this test is deterministic.

**The glyph regression test discriminates.** `MenuBarProviderGlyphTests` was run against the defect by temporarily pointing `menuBarAssetName` back at `Codex`. It failed as intended — *"Codex is 96% opaque; template rendering would paint it as a solid block"* — and passes against `CodexMenuBar`. A second interior-knockout assertion was written and then removed: the colored artwork's rounded corners satisfy it, so it did not discriminate the defect and would have been coverage without a defect behind it.

**The fix is confirmed at the rendering level.** Both compiled assets were loaded out of the built `.app` and drawn the way `.renderingMode(.template)` draws them — flat tint over every opaque pixel, composited on a dark menu bar. `Codex` renders as a filled rounded square, reproducing the reported symptom exactly. `CodexMenuBar` renders the Codex mark with its `>_` knockout intact. This proves the mechanism; it is **not** a substitute for inspecting the real menu bar.

**Unobserved.** The signed app was built but deliberately not launched, so nothing below has been seen and none of it may be reported as passing:

- the menu bar and the General **Menu Bar Preview** card in Light and Dark;
- the four footer key equivalents firing, and being unbound with the preference off;
- the General shortcut list at both Settings widths, Context Rail hidden and visible;
- the export save panel, the written JSON, the copied diagnostics report, and the cleared empty states;
- keyboard and VoiceOver navigation of every new control.

## Release integration re-verification — 2026-07-30

- The main macOS `xcodebuild` exited `0` with `** BUILD SUCCEEDED **`.
- The full SwiftPM suite executed 329 tests with 0 failures.
- `CODESIGN_IDENTITY=- zsh Scripts/build-app.sh` produced the optimized
  `0.0.1` / `266` candidate; the asset-catalog check passed, and strict signature
  verification passed for both the app and bundled Claude bridge. This was an
  ad-hoc verification build, not the Developer ID shipping artifact.
- `git diff --check` reported no whitespace errors.
- Signed-app visual, keyboard, VoiceOver, normal-export, and file-event acceptance
  was still unobserved at merge time.

## Post-release closeout — 2026-07-31

- Build `266` was Developer ID signed, notarized, stapled, tagged `v0.0.1`, and
  published.
- The user downloaded the uploaded artifact, verified it, launched it, and reported
  that the app works as intended.
- The release branch was deleted after merge. The historical sideways stacked-PR
  branches contained no patches absent from `main` and are eligible for cleanup.
- The observation is a release smoke test, not retrospective proof of every
  unrecorded VoiceOver, permission, long-copy, or manufactured conditional state.
