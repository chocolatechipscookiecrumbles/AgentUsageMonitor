# Menu Bar Popover — Figma v6 Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current plain `MenuBarExtra` menu with a SwiftUI port of the **v6 Figma menu bar popover** — a 340pt card with a provider tab strip, progress ring, window cards, freshness metadata, and a bottom action menu. Design reference and extracted tokens live in [docs/design/menu-bar-popover/](../../design/menu-bar-popover/SPEC.md).

**Supersedes** [2026-07-22-multiprovider-menubar-popover.md](2026-07-22-multiprovider-menubar-popover.md). That plan was written before the Figma export was reviewed and independently proposed a provider tab strip; the design already specifies one, so this plan absorbs it. The earlier plan's two hard findings still hold and are carried forward below.

## Layout revision (2026-07-22)

The exported layout was revised before porting — see [SPEC §6](../../design/menu-bar-popover/SPEC.md#6-revision--2026-07-22-supersedes-the-raw-v6-export). Summary:

- **Removed:** the header "Refresh Now" pill (duplicate — the action stays in the bottom menu), the **entire primary quota card** (plan name, "Lowest remaining", the 64pt ring), and the **entire freshness metadata card** (Collected/Source/Confirmation/Collector).
- **Moved:** the status pill from inside the primary card to the **header's right slot**.
- **Changed:** the header icon from a generic gradient glyph to the **active provider's own mark** (assets already in `reference/`).

Net effect: a shorter popover that is tabs → header (icon, title, pill) → window cards → credits (Codex only) → action menu. Port against SPEC §3, not against `reference/MenuBarDropdown.tsx`.

## Where this sits (state as of 2026-07-22)

- **Current menu is 168 lines of plain rows** across [QuotaMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaMenuView.swift) (31), [ConnectedQuotaMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ConnectedQuotaMenuView.swift) (66) and [CodexDisconnectedMenuView.swift](../../../CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexDisconnectedMenuView.swift) (71). It is Codex-only and has no provider concept.
- **Claude usage is already live** in Settings via `ClaudeUsageMonitor` → `ClaudeUsageDisplayModel`. The Claude tab consumes that mapper; it must not be reimplemented.
- **The Figma export is untracked** in git. `docs/design/menu-bar-popover/` is now the durable copy — treat it, not the loose folder, as the source of truth.

## Two blockers that must be settled first

**1. `MenuBarExtra`'s default `.menu` style cannot render this design.** It draws a native system menu of rows; a 340pt card with tabs and rings requires `.menuBarExtraStyle(.window)`. That switch **loses native menu behaviors** — automatic dismissal on action, keyboard traversal, standard metrics and highlighting. Every one of those must be re-implemented or consciously accepted. This is the single largest regression risk in the port and is why Task 1 exists.

**2. One menu bar label, several providers.** The design does not address the label at all. With Codex and Claude both live there is one glyph slot for two numbers. Carried from the superseded plan: recommended rule is **worst-case across providers**, shown **only with a provider glyph** — a bare percentage that silently switches which provider it refers to is misleading. Settle in Task 2.

## Design defects — do not port verbatim

From [SPEC.md §5](../../design/menu-bar-popover/SPEC.md):

1. **The "% used" number is wrong.** `WindowCard` renders `{remaining}% used` while also rendering `Remaining {remaining}%` — the same figure labelled two contradictory ways, and the first label is incorrect (61% used displays as "39% used"). Port as `{usedPct}% used`, or keep only "Remaining".
2. **Drop the `copilot` tab** — its capability gate has not passed; a tab with no real read is the "static preview" problem again.
3. **Header and `Collector` row are Codex-branded on every tab** — must be per-provider.
4. **The credits card is Codex-only** — Claude has no credit balance; must be conditional.
5. **No sign-in/disconnected state exists in the design** — Codex's browser/CLI sign-in and Claude's credential affordances need a home.

## Architecture

- **`MenuPopoverTheme`** — the tokens from SPEC §1–2 as a single Swift type (surfaces, radii, shadows, semantic colors, the ≤10/≤25 threshold rule) so no view hardcodes a hex.
- **`MenuPopoverChrome`** — shell: 340pt card, radius, border, shadow, window/card surfaces, light+dark.
- **Primitives**: `UsageProgressBar` (4pt), `StatusPill` (now header-mounted), `ProviderIconTile` (28pt, radius 8, renders the active provider's mark). The `UsageProgressRing` and `MetadataRow` primitives are **no longer needed** — the revision removed the primary quota card and the freshness metadata card.
- **`MenuProviderTabStrip`** — driven by `AgentProvider` (already carries `tabTitle`, `systemImage`, tint) filtered to providers with a real read.
- **`CodexMenuContent`** — window cards + credits card, mapped from the existing `QuotaPresentation`/`QuotaDisplayState`. **Behavior-preserving**: every affordance in today's menu must survive. Per the revision, there is no primary quota card and no freshness metadata card.
- **`ClaudeMenuContent`** — 5h/7d window cards, shared-pool caveat, explicit unavailable state, built from `ClaudeUsageDisplayModel`. No credits card. **Open question from the revision:** provenance (OAuth vs statusLine vs cache) has no home now that the metadata card is gone — see Task 5a.
- **`MenuActionFooter`** — Refresh Now / Notification Settings / Preferences… / Quit.
- **Presentation stays in testable structs** (`MenuBarLabelPresentation`, `ClaudeUsageDisplayModel`, a new `CodexMenuPresentation`), never in view bodies.

**Tech Stack:** SwiftUI, Combine, XCTest. No new dependencies. SVG provider marks in `docs/design/menu-bar-popover/reference/` may be converted to asset catalog entries or redrawn as `Path`s.

## Global constraints

- **No provider tab without a real read** (generalizes the Claude capability gate).
- **The label never shows a bare percentage** without identifying its provider.
- **Never render a missing value as `0%`** — absent data shows as unavailable, per gate criterion #5.
- **Cached/stale/expired must stay visibly labelled** (probe plan §7/§9) — the design's amber "Showing Last Confirmed Snapshot" strip satisfies this for Codex; Claude's equivalent comes from `stalenessNotice`.
- **No behavior regressions in the Codex menu.** Sign-in, alerts toggle, refresh, notification-settings link, forecasts all keep working.
- **TDD for all presentation logic**; full suite green each task.

---

## Task 1: Prove `.window` style is viable (SPIKE — gate)

**Why first:** if popover dismissal can't be made to work acceptably, the whole port is in question and it is far cheaper to learn that now.

- [ ] **Step 1:** Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)` with a placeholder 340pt card behind a temporary flag.
- [ ] **Step 2:** Manually verify and **write down** the result for: clicking an action dismisses the popover; clicking outside dismisses; Escape dismisses; the menu bar icon toggles; VoiceOver/keyboard focus is not trapped.
- [ ] **Step 3:** If dismissal does not work by default, implement it explicitly (e.g. an environment-injected dismiss handler each action calls) and re-verify.
- [ ] **Step 4: Record the finding** in this plan. If unresolvable, stop and reconsider — a popover that will not close is worse than a plain menu. **Commit.**

## Task 2: Settle the multi-provider label rule

- [ ] **Step 1: Failing tests** (`MenuProviderSummaryTests.swift`): summary carries provider + percent + availability; "most at risk" picks highest utilization; providers with no data are excluded, not treated as 0%; ties resolve deterministically.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3:** Record the chosen rule in this plan, then implement `MenuProviderSummary` + selection.
- [ ] **Step 4:** Extend `MenuBarLabelPresentation`: one provider → unchanged from today (no regression); two → at-risk provider **with glyph**; none → existing unavailable label. **Run the full suite. Commit.**

## Task 3: Theme and primitives

- [ ] **Step 1: Failing tests** (`MenuPopoverThemeTests.swift`): the threshold rule returns danger ≤10, warning ≤25, success above; boundary values (exactly 10, exactly 25) resolve as specified; light and dark both return a surface for every token.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** `MenuPopoverTheme`, `UsageProgressBar`, `UsageProgressRing`, `StatusPill`, `MetadataRow` per SPEC §1–2.
- [ ] **Step 4: Run to verify they pass. Commit.**

## Task 4: Shell + provider tab strip

- [ ] **Step 1: Failing tests**: `availableProviders` includes Codex always, Claude only when its state is usable, **never Copilot**; the persisted selection falls back to the default when the persisted provider is unavailable.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** `MenuPopoverChrome` + `MenuProviderTabStrip` + `ProviderIconTile` + the header row (provider icon, title/subtitle, status pill) + the root `MenuBarPopoverView` (strip, header, content, footer). The provider marks are full-color SVGs, so pick the tile background deliberately rather than reusing the old blue-violet gradient.
- [ ] **Step 4: Run the full suite. Commit.**

## Task 5: Codex content — behavior-preserving port

- [ ] **Step 1: Failing tests** for `CodexMenuPresentation`: window rows (used %, remaining %, reset time + time-until), credit balance and reset-credit expiries, and the status-pill state. Assert **`% used` shows used, not remaining** (design defect #1 — still unfixed in the revision). No primary-card or metadata-row assertions; those elements are removed.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** `CodexMenuContent` from `QuotaPresentation`/`QuotaDisplayState`, including the cached warning strip and the unavailable card.
- [ ] **Step 4: Manually verify every existing affordance still works** — sign-in (browser + CLI), alerts toggle, refresh now, notification-settings link, forecasts, cached/paused status. **Commit.**

## Task 5a: Decide where the removed information goes (DESIGN GATE)

The revision removed three pieces of information from the popover. Settle each **before** building Claude's tab, since two of them affect it directly.

- [ ] **Plan name** ("Pro") — had no home outside the removed card. Decide: header subtitle, a window-card header, or accept that plan tier lives only in Settings.
- [ ] **"Lowest remaining %"** — the at-a-glance figure and ring are gone. Decide whether per-window numbers suffice, or whether the menu bar label now carries that role (it overlaps with Task 2's rule).
- [ ] **Provenance** (`Source` / `Collector`) — **the consequential one.** Claude's data can come from OAuth, a statusLine capture, or cache, and these differ materially in freshness and authority; `claude_probe_plan` §9 asks for source labelling. Options: fold the source into the status pill text, put it in the header subtitle, or accept the loss on the menu given `ClaudeUsageStatusView` in Settings already shows "Read from: <source> · <relative time>". **Record the choice here.**
- [ ] **Commit the decision** as an edit to this plan before Task 6.

## Task 6: Claude content

- [ ] **Step 1: Implement** `ClaudeMenuContent` from `ClaudeUsageDisplayModel`: plan, five-hour and weekly window cards, source label + relative capture time, the shared-pool caveat, `stalenessNotice` surfaced like the Codex cached strip, and the explicit unavailable state with the credential affordance.
- [ ] **Step 2:** Hide Codex-only furniture (credits card, `Collector: Codex App Server`) on this tab; the header must name the active provider.
- [ ] **Step 3:** Manual verification against the live account. **Commit.**

## Task 7: Persist the selected tab

- [ ] **Step 1: Failing tests**: selection round-trips through `AppSettings`; an unavailable persisted provider falls back rather than showing an empty tab.
- [ ] **Step 2: Implement. Run the full suite. Commit.**

## Task 8: Retire the old menu and document

- [ ] **Step 1:** Remove `QuotaMenuView`/`ConnectedQuotaMenuView`/`CodexDisconnectedMenuView` once their affordances are confirmed ported. Keep `CodexDisconnectedMenuView`'s sign-in copy if reused.
- [ ] **Step 2:** Update the planning board and extend [the verification guide](../../claude-usage-verification.md) with menu-level manual checks.
- [ ] **Step 3: Commit.**

---

## Explicitly deferred (not dropped)

- **GitHub Copilot tab** — blocked on its capability gate.
- **Per-provider view models.** `QuotaViewModel` stays one type; splitting it collides with recent changes and should follow this port.
- **Desktop widget / watch complication** — the export also contains `DesktopWidget.tsx` and `WatchComplication.tsx`; out of scope here.
- **Tab reordering / pinned primary provider** — depends on Task 2's outcome.

## Completion criteria

- The menu bar shows the revised v6 popover: 340pt card, provider tabs (Codex + Claude only), header with the active provider's icon and the status pill, window cards, credits (Codex only), action footer — light and dark.
- **The popover dismisses correctly** after every action (Task 1's gate).
- Every Codex affordance from the old menu still works; no data regression.
- Claude's tab labels stale/cached data and shows an explicit unavailable state rather than zeros.
- The `% used` defect is fixed, not ported.
- The label never shows a bare percentage without its provider.
- Full suite green.
