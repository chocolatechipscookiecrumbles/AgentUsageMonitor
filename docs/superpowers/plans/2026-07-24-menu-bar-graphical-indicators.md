# Menu-Bar Graphical Indicators — Implementation Plan (for review)

> **Status: IMPLEMENTED; signed-app visual acceptance remains.** This resumes Workstream B of the [prototype-finalization plan](2026-07-24-prototype-finalization.md) with the user-provided UI samples ("Two Parallel Stacked Bars" and "Overlayed Progress Bars"). A dedicated Settings destination for display modes is **deferred**.
>
> **Selector trimmed (2026-07-24, by user direction):** the menu-bar Style options are now **"5-hour and weekly"** (text), **"Bars"** (stacked), and **"Combined"** (default). The **Gauge** text mode and the experimental **Single Provider** bar mode were removed. The text "5-hour and weekly" mode now shows both windows for Codex again (it had been overridden by the removed gauge's multi-provider glyph + single-percentage behavior). Persisted values for the removed modes fall back to the new default (**Combined**).

**Goal:** Add two new selectable menu-bar indicator modes that show, per provider, the **remaining** quota for the five-hour and weekly windows as bars (no text), reusing each provider's brand color.

- **Option 1 — "Stacked bars":** four bars total. Each provider = one row of two thin stacked bars (5-hour on top, weekly below); Provider 1's pair above Provider 2's pair. Weekly is a lower-emphasis version of the same provider color.
- **Option 2 — "Combined bars":** two bars total, one per provider. Within one track, the weekly fill is the lower-emphasis background and the five-hour fill is the higher-emphasis foreground; both start at the leading edge, each sized by its own remaining %. A deterministic layered treatment keeps the weekly layer visible even when 5-hour ≥ weekly.
- **Option 3 — "Single Provider":** when exactly one provider is connected, show only that provider's two stacked bars (5-hour above weekly). With zero or two connected providers, retain the full provider layout rather than choosing a provider arbitrarily.

All fills represent **remaining** quota and shrink right-to-left from a left anchor.

---

## Current source state (inspected 2026-07-24)

- **Selector enum:** `Settings/MenuBarDisplayStyle.swift` — `enum MenuBarDisplayStyle: String, CaseIterable` with `.gaugeAndLowest` ("Gauge") and `.fiveHourAndWeekly` ("5-hour and weekly"). `id`/`title` per case.
- **Selector UI:** `Settings/GeneralSettingsView.swift` renders it as a **segmented** `Picker` at `SettingsLayoutMetrics.compactSegmentedControlWidth`. A "Show" segmented picker below selects `QuotaValueMode` (Used/Remaining).
- **Persistence:** `AppSettings.menuBarDisplayStyle` (key `menuBar.displayStyle`), already persisted by rawValue; loaded with a `.gaugeAndLowest` default.
- **Render path:** `Menu/MenuBarStatusLabel.swift` builds `MenuBarLabelPresentation(displayState:providerSummaries:style:valueMode:)` and renders `Menu/MenuBarLabelView.swift` (an `HStack` of optional provider glyph, gauge, `Text`, pause marker — **text only**).
- **Per-provider data:** `Menu/MenuProviderSummary.swift` maps `displayState` (Codex) and `claudeState` (Claude) to a single `usedPercent` (highest of the two windows) + `Freshness` (`confirmed`/`cached`/`passive`) + `Availability`. It **does not** carry the two windows separately, and it already owns the canonical provider order (`codex` 0, `claudeCode` 1, `githubCopilot` 2) and window-eligibility (drops `hasReset` Claude windows).
- **Windows source:** Codex `displayState.displayedRecord?.presentation.fiveHour?.remainingPercent` / `.weekly?.remainingPercent` (`QuotaWindow.remainingPercent = max(0,100-used)`); Claude via `ClaudeUsageDisplayModel(presentation:).fiveHour` / `.sevenDay` (each `Window.usedPercent` + `hasReset`).
- **Colors:** `AgentProvider.settingsPresentationTint` — Codex `#576DFF`-ish, Claude `#D97757`. (Reuse; do not duplicate.)
- **Preview:** `Settings/GeneralSettingsContextView.swift` "Menu Bar Preview" card renders `MenuBarLabelView` via the **single-provider** `MenuBarLabelPresentation(displayState:style:valueMode:)` init — Codex only, no Claude summary.
- **Tests:** `Tests/.../MenuProviderSummaryTests.swift` (pure XCTest). No `MenuBarLabelPresentation` tests and no snapshot-testing infrastructure in the package.

---

## Design

### Selector cases and names

Add two cases to `MenuBarDisplayStyle`:

| case | rawValue | `title` (user-facing) |
| --- | --- | --- |
| `.stackedBars` | `"stacked-bars"` | **Bars** *(open: "Stacked bars" / "Windows")* |
| `.combinedBars` | `"combined-bars"` | **Combined** *(open: "Combined bars" / "Overlay")* |
| `.singleProviderBars` | `"single-provider-bars"` | **Single Provider** |

Persistence is unchanged: they ride the existing `menuBar.displayStyle` key. An unknown stored value already falls back to `.gaugeAndLowest`.

**Selector treatment (open decision):** four options no longer fit a segmented control at the compact width. Recommended: change the "Style" `Picker` to the default **menu (dropdown) style** (`.pickerStyle(.menu)`), which holds four named options cleanly and needs no dedicated destination. Alternative: keep segmented but shorten every title. (Segmented with 4 graphical modes will be cramped and is not recommended.)

**`QuotaValueMode` ("Show") interaction:** the bar modes are **always remaining** by spec, so the "Show" Used/Remaining control does not affect them. The plan will leave "Show" in place (it still governs the text modes) and simply ignore it in the bar renderers. (Open: optionally disable/greyed "Show" when a bar mode is selected — recommended as a small follow-up, flagged, not required.)

### Data model (new, pure, testable)

Introduce `Menu/MenuBarQuotaBars.swift`:

```
struct MenuBarQuotaBars: Equatable {
    enum Fill: Equatable { case value(Double)   // normalized remaining 0...1
                           case unavailable }    // no eligible reading
    let provider: AgentProvider
    let fiveHour: Fill
    let weekly: Fill
    let freshness: MenuProviderSummary.Freshness?   // nil when fully unavailable
    var hasAnyValue: Bool { … }
}
```

- Static builders mirror `MenuProviderSummary`: `codex(displayState:)` and `claude(usageState:now:)`, reusing the existing window-eligibility (drop `hasReset`) and freshness mapping.
- **Value mapping:** `remaining = clamp(remainingPercent, 0, 100) / 100` → `Fill.value` clamped to `0...1`; a missing/expired/unavailable window → `Fill.unavailable`. Malformed values below 0 or above 1 are clamped by the same `clamp`.
- **Ordering / single provider:** a top-level builder returns `[MenuBarQuotaBars]` sorted by the existing provider order, **including only providers that are configured/supported** (Codex always; Claude when it has a monitor). When only one provider is configured, only that provider's row(s) render — no empty second slot.
- **Fallbacks:**
  - *Unavailable / disconnected / loading (no data):* both `Fill.unavailable`; row still occupies its fixed slot with an "empty track" treatment (see dimensions) so width/height do not jump.
  - *Partially available:* the available window renders its fill; the other renders `unavailable`.
  - *Stale (cached/passive):* fills render at a reduced opacity multiplier (freshness-driven), no text. (Open: exact stale opacity.)
  - *Unlimited:* the current models have no "unlimited window" representation; an unlimited/uncapped window surfaces as either a missing window (→ `unavailable`) or 100% remaining (→ full bar). The plan will **not** invent an unlimited state; it maps whatever the presentation yields. Flagged as an open data question if a real unlimited case exists.

### Renderers (new SwiftUI views)

`Menu/MenuBarBarsView.swift` with two internal layouts selected by style; `MenuBarStatusLabel` chooses the bar view for `.stackedBars`/`.combinedBars` and the existing `MenuBarLabelView` for the text modes.

- **Fixed width:** the whole bar block has a constant frame width regardless of fill, so the menu-bar item never resizes on refresh (a concrete improvement over the text modes, whose width varies with `5%` vs `100%`).
- **Left anchor:** each fill is a leading-aligned rounded rectangle over a full-width rounded track; width = `trackWidth * remaining`, with a **minimum visible fill** (~2pt) so a near-empty non-`unavailable` bar still shows a sliver, while a genuinely `unavailable` window shows only the empty track (visually distinct from "0% remaining").
- **Option 1 (stacked):** per provider, a `VStack` of two bars (5-hour solid tint on top, weekly tint-at-lower-opacity below); providers stacked with a larger inter-provider gap.
- **Option 2 (combined):** per provider, one track containing the weekly fill at **full track height, lower opacity** (background) and the five-hour fill as an **inset (reduced-height, vertically centered), full-opacity foreground**. This is the deterministic treatment that keeps weekly visible when 5-hour ≥ weekly: in the overlap region weekly shows as thin bands above/below the inset 5-hour bar; beyond the shorter fill, the longer window shows on its own. (Alternative considered: a thin lower "lane" for weekly; rejected because it reads as two bars rather than a layered single bar. Open for approval.)
- **Colors:** `provider.settingsPresentationTint` for the solid/foreground; the same tint at a fixed lower opacity for weekly/background; the track is the tint (or neutral) at a low opacity. No new color constants.
- **Light/dark:** provider tints are chosen to read on both; the track opacity is tuned so the empty track is visible on a light and a dark menu bar. Rendered with `.blendMode`-free plain fills; verified in both appearances during manual validation.

### Accessibility

The block sets one combined `accessibilityLabel` even though there is no visible text, e.g.:
`"Codex: five-hour 49% remaining, weekly 76% remaining. Claude: five-hour unavailable, weekly 62% remaining, cached."`
Built from the same `MenuBarQuotaBars` model (pure, testable), with `unavailable` and freshness spoken.

### Preview in the selector

Update `GeneralSettingsContextView`'s "Menu Bar Preview" card to build the presentation with **both** provider summaries (Codex + Claude) so the bar modes preview correctly, and to render the bar view for the bar modes. (No per-option preview gallery — that belongs to the deferred dedicated destination.)

---

## 1. Files expected to be modified

- `Settings/MenuBarDisplayStyle.swift` — add `.stackedBars`, `.combinedBars` + titles.
- `Settings/GeneralSettingsView.swift` — Style picker treatment (segmented → menu) to fit four options.
- `Settings/GeneralSettingsContextView.swift` — preview uses both provider summaries + renders bar view for bar modes.
- `Menu/MenuBarStatusLabel.swift` — branch to the bar view for the two new styles.
- `Menu/MenuBarLabelPresentation.swift` — only if a shared helper is cleaner; otherwise untouched (bar modes use the new model, not the text presentation).
- Docs: `docs/design/` note (short) if a rendering contract is worth recording; `planning-board.md` and the finalization plan's Workstream B status.

## 2. New types / reusable views

- `Menu/MenuBarQuotaBars.swift` — pure per-provider two-window remaining model + builders + accessibility-string helper.
- `Menu/MenuBarBarsView.swift` — the SwiftUI renderer (stacked + combined layouts, fixed width, min-fill, track).
- (Possibly) a tiny `MenuBarBarMetrics` constants holder for dimensions, mirroring `MenuPopoverTheme` conventions.

## 3. Test cases to add

Unit (pure, `MenuBarQuotaBarsTests`):
- remaining mapping: 100→1.0, 0→0.0, 49→0.49; clamp <0→0 and >100→1.
- unavailable window → `Fill.unavailable` (distinct from `value(0)`).
- Claude expired window (`hasReset`) → `unavailable`; the eligible window still maps.
- partial availability (one window only) per provider.
- freshness mapping (confirmed/cached/passive) and stale opacity multiplier value.
- provider ordering (Codex before Claude) and single-provider list (only configured providers).
- accessibility string for full / mixed / unavailable / stale states.

Rendering-geometry (no pixel snapshots — none exist in-package):
- `MenuBarBarsView` (or a pure `layout` function) computes fill widths for representative states (full/medium/low/critical/mixed/one-provider-critical/balanced) equal to `trackWidth * remaining` with the min-fill floor; `unavailable` yields zero fill width (empty track).
- fixed total width is identical across all fill states (width-stability guard).

Manual validation (signed app, both appearances): full, medium, low, critical, mixed-provider, disconnected, single-provider — per the finalization branch's visual-verification waiver (recorded as observed/unobserved honestly).

## 4. Visual decisions — RESOLVED 2026-07-24

1. **Selector control:** switch "Style" to the dropdown **menu** picker (for now, until a dedicated page exists). ✅
2. **Mode names:** **"Bars"** (stacked) and **"Combined"**. ✅
3. **Option 2 layered treatment:** **inset foreground** 5-hour over full-height weekly, **and** differentiate by tint too (weekly lower-opacity, 5-hour solid) — so the two layers differ by both height and tint. ✅
4. **Dimensions (updated July 24):** total block **width 34pt**. Option 1 and Single Provider: bar height 2pt, within-pair gap 1.5pt, between-provider gap 3pt, radius 1pt. Option 2: track height 6pt with a 3.5pt inset 5-hour bar, between-provider gap 3pt, radius 1.5pt. Minimum visible fill 2pt. ✅
5. **Stale/cached treatment:** opacity multiplier **0.5** on that provider's bars; no text/marker. (Default; adjustable.)
6. **`unavailable` window treatment:** empty low-opacity track (~0.15 tint). ✅
7. **"Show" (Used/Remaining):** leave as-is (governs text modes only); the bar modes are always remaining. A disable-when-bar-mode tweak is a small optional follow-up, not in scope.
8. **Provider tint:** reuse `settingsPresentationTint`; verify legibility in both appearances during manual validation. No menu-bar-specific tint variant unless legibility fails.

## 5. Implementation order — DONE (approved 2026-07-24)

1. [x] `MenuBarDisplayStyle` cases (`.stackedBars`/`.combinedBars`) + `isGraphical`; text presentation falls back to gauge (`ea334fe`).
2. [x] `MenuBarQuotaBars` model + builders + unit tests (`ea334fe`).
3. [x] `MenuBarBarsView` + `MenuBarBarMetrics` renderer (stacked + combined) + geometry tests (`46402e6`).
4. [x] `MenuBarStatusLabel` branches on style; fixed width, updated to 34pt in the July 24 follow-up (`46402e6` plus working-tree follow-up).
5. [x] Accessibility description on the model + tests (`46402e6`).
6. [x] Style picker → dropdown menu; preview renders bar modes with both providers (`46402e6`).
7. [~] **Pending:** the Developer ID signed app builds successfully and 272 tests pass, but the signed-app manual validation matrix (full/medium/low/critical/mixed/disconnected/single-provider, light+dark) remains. An existing user-owned app process was running during the July 24 follow-up, so it was left untouched and the new bundle was not launched for visual inspection. Reconcile the board on acceptance.
8. [x] **July 24 follow-up:** extend graphical tracks from 22pt to 34pt and add the dedicated **Single Provider** style, which collapses to one 5-hour/weekly pair only when exactly one provider is connected.

## 6. Checkpoint — approval required before production implementation

**No production code will be written until you approve.** Please confirm:

- the two mode **names** (decision 2),
- the **Option 2 layered treatment** (decision 3),
- the **selector control** change (decision 1),
- and the **dimensions** (decision 4) — or tell me to proceed with the recommended defaults for all open items.

On approval I will implement in the order above, one reviewable commit per step, keeping the full test suite green.
