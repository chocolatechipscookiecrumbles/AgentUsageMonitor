# Menu Bar Popover — Design Spec (from Figma export v6)

Extracted from `reference/MenuBarDropdown.tsx` (the v6 "agent view update" Figma export) so the design survives independently of the untracked `High-fidelity macOS menu UI v6 agent view update/` folder and is usable without running the React app.

**Provenance:** `High-fidelity macOS menu UI v6 agent view update/src/components/MenuBarDropdown.tsx`, 473 lines, dated 2026-07-19. That folder is **untracked** in git — this directory is the durable copy.

---

## 1. Shell

| Property | Value |
|---|---|
| Width | `340px` fixed |
| Corner radius | `14px` |
| Border | `1px` — light `rgba(0,0,0,0.07)`, dark `rgba(255,255,255,0.07)` |
| Shadow | light `0 16px 48px rgba(0,0,0,0.14), 0 0 0 0.5px rgba(0,0,0,0.08)`; dark `0 16px 48px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(255,255,255,0.07)` |
| Window bg | light `#f5f5f7`, dark `#242424` |
| Card ("group") bg | light `#ffffff` + `0 1px 3px rgba(0,0,0,0.06)`; dark `rgba(255,255,255,0.055)`, no shadow |
| Card radius | `10px` |

Design intent noted in the source: cards should *"almost blend into the window."*

## 2. Semantic colors

| Token | Value | Use |
|---|---|---|
| Accent / interactive | `#0a84ff` | Refresh, active tab, links |
| Success | `#30d158` | remaining > 25% |
| Warning | `#ff9f0a` | remaining ≤ 25%, cached state |
| Danger | `#ff453a` | remaining ≤ 10% |
| Neutral | `#8e8e93` | unavailable |
| Primary text | light `#1c1c1e`, dark `#ffffff` | |
| Secondary text | light `black/38%`, dark `white/40%` | |

**Threshold rule** (drives bar, ring, and numerals):
`remaining ≤ 10` → danger · `remaining ≤ 25` → warning · else success.

## 3. Structure (top to bottom)

1. **Provider tab strip** — `codex` / `claude` / `copilot`, equal-width, `12px` medium. Active: `#0a84ff` text with a `1.5px` bottom border in `#0a84ff`, offset `-1px` to sit on the divider. Strip bg light `#ebebeb`, dark `#1e1e1e`.
2. **Header row** — `28×28` gradient app tile (`#0a84ff` → `#5e5ce6`, radius `8px`), title `13px` semibold, subtitle `11px` (`Updated 11:42:13 AM`, or `Refreshing…`). Right: **Refresh Now** pill, `11px` medium, tinted `rgba(10,132,255,0.09)`, spinner-swapped and disabled while refreshing.
3. **Cached warning strip** (cached state only) — `rgba(255,159,10,0.10)` bg, clock icon, "Showing Last Confirmed Snapshot".
4. **Primary quota card** — "CURRENT PLAN" `10px` uppercase tracked label, plan name `20px` bold, "Lowest remaining" `10px`, big numeral `26px` bold in threshold color, and a `64px` **progress ring** (stroke `4.5`, rounded cap, `-90°` rotation) with the numeral centred. Confirmation badge beneath.
5. **Window cards** — two stacked rows in one card, divided by an inset `border-t mx-4`: "Five Hour Window" and "Weekly Window". Each: title `12px` medium; right value `12px` semibold in threshold color; `4px` progress bar (radius full); footer row `11px` with "Remaining N%" left and "Resets 3:42 PM · 2h 18m" right. Dimmed to `opacity-75` when cached.
6. **Credits card** — credit-card icon + "Credit Balance" with `18px` bold value; divider; "Earned Reset Credits" with "N Available" in accent; then calendar-icon expiry rows at `11px`.
7. **Freshness metadata card** — label/value rows at `11px`, divided: `Collected`, `Source`, `Confirmation` (accent-colored per state), `Collector`.
8. **Bottom action menu** — full-width rows `13px` with `13px` leading icons: Refresh Now (disabled while refreshing), Notification Settings, Preferences…, Quit. Hover light `black/3%`, dark `white/5%`.

## 4. States

`confirmed` · `cached` · `refreshing` · `unavailable`

**Unavailable** replaces the whole content region with a centred card: `40px` circle at `rgba(142,142,147,0.10)`, warning glyph, "Unable to Read Usage" `13px` semibold, an `11px` explanation capped at `190px`, then **Retry** (filled `#0a84ff`) and **Preferences** (subtle fill) buttons.

## 5. Issues to resolve before porting

These are defects/mismatches in the design as exported — do not port them verbatim.

1. **The "% used" figure is wrong.** `WindowCard` computes `remaining = 100 - usedPct`, then renders `{remaining}% used` in the top-right *and* `Remaining {remaining}%` in the footer. With `usedPct = 61` it shows "39% used" and "Remaining 39%" — the same number labelled two contradictory ways, and the top-right label is simply incorrect. Port as `{usedPct}% used`, or drop the top-right label and keep only "Remaining".
2. **`copilot` has a tab.** GitHub Copilot's capability gate has not passed. Shipping a tab for a provider with no real read is the exact "static preview" problem the Claude gate rejected. Omit it.
3. **The header is Codex-branded on every tab.** Title reads "Codex Usage Monitor" and the metadata card says `Collector: Codex App Server` regardless of the active provider. Per-provider content is required.
4. **The credits card is Codex-only.** Claude has no credit balance or earned reset credits; it has plan/5h/7d/extra-usage. This card must be conditional, not shared.
5. **All values are hardcoded mock data** (`61`, `72`, `143`, `"3:42 PM"`, `"Pro"`). It is a visual reference, not a data contract.
6. **No sign-in / disconnected state.** The design assumes a connected account. Codex's existing browser/CLI sign-in and Claude's credential-method affordances have no home in this layout and must be designed in.
