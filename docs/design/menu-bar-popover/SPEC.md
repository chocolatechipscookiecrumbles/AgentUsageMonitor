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

**Threshold rule** (drives bar and numerals), stated in *used* terms and
tracking usage regardless of whether a surface shows used or remaining
(see §7): `used > 90` → danger · `used 75…90` → warning · `used < 75` → success.
Equivalent in remaining terms: `remaining < 10` → danger · `remaining ≤ 25` → warning.

## 3. Structure (top to bottom) — REVISED 2026-07-22

This is the **current target layout**, after the revision in §6. It is materially shorter than the original export: three elements were removed and the status pill was relocated.

1. **Provider tab strip** — `codex` / `claude` / `copilot`, equal-width, `12px` medium. Active: `#0a84ff` text with a `1.5px` bottom border in `#0a84ff`, offset `-1px` to sit on the divider. Strip bg light `#ebebeb`, dark `#1e1e1e`.
2. **Header row** —
   - **Left:** `28×28` rounded tile (radius `8px`) showing the **active provider's own icon** — Codex mark on the Codex tab, Claude mark on the Claude tab. *Not* a generic gradient glyph. Assets: `reference/codex-color.svg`, `reference/claudecode-color.svg`.
   - **Middle:** title `13px` semibold (app name), subtitle `11px` (`Updated 11:42:13 AM`, or `Refreshing…`).
   - **Right:** the **status pill** (`Confirmed` / `Cached` / `Refreshing` / `Unavailable`) — a filled capsule with a leading `6px` state dot, `11px` medium, colored per state (success `#30d158`, warning `#ff9f0a`, accent `#0a84ff`, neutral `#8e8e93`) on a low-alpha tint of the same hue.
3. **Cached warning strip** (cached state only) — `rgba(255,159,10,0.10)` bg, clock icon, "Showing Last Confirmed Snapshot".
4. **Window cards** — two stacked rows in one card, divided by an inset `border-t mx-4`: "Five Hour Window" and "Weekly Window". Each: title `12px` medium; right value `12px` semibold in threshold color; `4px` progress bar (radius full); footer row `11px` with "Remaining N%" left and "Resets 3:42 PM · 2h 18m" right. Dimmed to `opacity-75` when cached.
5. **Credits card** *(Codex only)* — credit-card icon + "Credit Balance" with `18px` bold value; divider; "Earned Reset Credits" with "N Available" in accent; then calendar-icon expiry rows at `11px`.
6. **Bottom action menu** — full-width rows `13px` with `13px` leading icons: Refresh Now (disabled while refreshing), Notification Settings, Preferences…, Quit. Hover light `black/3%`, dark `white/5%`.

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

---

## 6. Revision — 2026-07-22 (supersedes the raw v6 export)

Directed revision of the exported layout. `reference/MenuBarDropdown.tsx` still holds the **original** export; §3 above holds the **target**. Where they disagree, §3 wins.

### Removed

| # | Element | Note |
|---|---|---|
| 1 | **Header "Refresh Now" pill** (top-right of header) | The action itself is **not** lost — "Refresh Now" remains in the bottom action menu. This removes a duplicate affordance and frees the header's right slot for the status pill. |
| 2 | **Primary quota card, entirely** | The whole "CURRENT PLAN / Pro / Lowest remaining 39% / ring" block, including the `64px` progress ring and the confirmation badge in its original position. |
| 3 | **Freshness metadata card, entirely** | All four rows: `Collected`, `Source`, `Confirmation`, `Collector`. |

### Moved

- **Status pill → header, right side.** Previously sat inside the primary quota card (below the plan/ring). Now occupies the slot vacated by the Refresh Now button. It is the only surviving carrier of confirmation state in the header region.

### Changed

- **Header icon is now the active provider's icon.** Was a generic gradient tile with a "gauge" glyph (`#0a84ff` → `#5e5ce6`). Now shows the provider mark for the selected tab, using the existing assets in `reference/`. Note these are **full-color SVG marks**, not monochrome glyphs, so the gradient tile background may need to become a neutral or provider-tinted container rather than the blue-violet gradient.

### Retained

Provider tab strip · header title + "Updated HH:MM:SS" · cached warning strip · window cards · credits card · bottom action menu.

### Consequences of the removals — decide before implementing

These follow mechanically from the three removals and are **not yet resolved**:

1. **The plan name is no longer displayed anywhere.** "Pro" existed only in the removed primary card. If plan tier should remain visible, it needs a new home (e.g. the header subtitle, alongside or replacing "Updated …").
2. **The at-a-glance summary figure is gone.** "Lowest remaining %" and its ring were the single number telling you how close you are to *any* limit. Per-window numbers remain, but the user must now compare them mentally. This is a deliberate simplification; flagging it because it was the layout's visual focal point.
3. **Provenance is no longer shown.** The `Source` and `Collector` rows are gone, so the popover no longer says *which tier served the data*. For Codex that is minor (one collector). **For Claude it is material**: OAuth vs statusLine capture vs cache are meaningfully different in freshness and authority, and `claude_probe_plan` §9 calls for source labelling. Options: fold the source into the status pill, put it in the header subtitle, or accept the loss on the menu and keep provenance in Settings (where `ClaudeUsageStatusView` already shows "Read from: <source> · <relative time>").
4. **Staleness is still covered** — the cached warning strip and the status pill both survive, so a cached read remains visibly labelled. No regression against the capability gate on that point.

### Unresolved defect carried over

The **"% used" figure is still wrong** in the revised design. Both images show "39% used" beside "Remaining 39%" (and "28% used" beside "Remaining 28%") — the same number labelled two contradictory ways, while the progress bar fills to the *other* value. This was not addressed by the revision and still must be fixed rather than ported. See §5.1.

---

## 7. Refinements — 2026-07-23 (supersede §3/§6 where they disagree)

Directed refinements after the first shipped port. Where these disagree with §3/§6, these win.

- **Header freshness line is standardized across providers:** `Updated: <time> · <relative>` (e.g. `Updated: 3:42:05 PM · 3 minutes ago`). Replaces §3.2's `Updated 11:42:13 AM` and §6-Retained's `Updated HH:MM:SS`. Computed once at render — no timer, so it does not tick while open.
- **Header title is the provider name only** — `Codex` / `Claude`, not `<App> Usage Monitor`. Resolves the header-branding half of §5.3 (the metadata card was already removed in §6). The footer **Quit Codex Usage Monitor** keeps the app name.
- **Claude provenance resolved (was §6-consequence-3):** the source label moves into a compact content caption — `Read from: <source>` — beneath the window card, matching Settings' "Read from" wording. This **supersedes** the earlier decision to put it in the header subtitle, so the freshness line stays identical across tabs while provenance stays visible on the menu.
- **Plan name (§6-consequence-1):** resolved as *Settings only* — not re-added to the popover on either tab.
- **Provider icon fill:** Codex's mark fills the full `28×28` tile (clipped to the `8px` corners) with no inset, because it already carries its own square background; providers with a transparent glyph (Claude, Copilot) keep the inset. Refines §3.2-left / §6-Changed.
- **Quota-alerts toggle removed from the popover** (it lives in Settings). The denied-notification recovery it used to host is kept as a **slim strip shown on both tabs** whenever `notificationAuthorizationState == .denied` — warning text + **Open System Notification Settings**. The footer **Notification Settings** row (app Settings) is unchanged.
- **Credits card balance is rounded to 4 significant figures** in the popover; Settings keeps full precision. Refines §3.5.

### Deferred (documented, not yet implemented)

- **Refresh Now should keep the popover open.** Unlike the other footer commands (which dismiss first), the footer **Refresh Now** should *not* dismiss — it should stay open and show the in-place `Refreshing…` header/footer state so the user sees the result without reopening. Implementation deferred.

## 8. Visual fixes — 2026-07-23 (round 2)

- **Single rounded piece.** The `MenuBarExtra(.window)` host window is made transparent (`isOpaque = false`, clear background) so only the rounded `MenuPopoverChrome` shell shows; the window server draws the matching rounded shadow, so the chrome no longer carries its own SwiftUI shadow. Fixes the four corner artifacts where the squarer opaque window showed behind the shell. *(Fallback if this ever regresses: square the shell to match the window.)*
- **Header timestamp drops seconds** — `Updated: 22:13 · just now` (was `22:13:10`). The relative half already carries recency.
- **Tab hit target is the full column** (already true) **and taller** — strip height `36 → 44px`, with a full-column hover fill so the target reads as large as it is.
- **Footer is flush** — the action rows have no vertical padding, so **Refresh Now** sits against the divider and **Quit** against the bottom edge.
- **Usage color threshold** standardized to the §2 used-based rule (`< 75` green, `75…90` yellow, `> 90` red), applied to the popover bars and numerals only. Settings' provider-tinted bars are intentionally left as-is (accepted 2026-07-23).
