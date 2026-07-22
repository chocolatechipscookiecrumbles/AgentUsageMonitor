# PR 3 — Menu bar popover: design preservation and port plan

**Branch:** `feature/menu-bar-popover-update` → `main` · **Merge after PR 1** · **Docs only — no production code**

## Summary

- Preserves the v6 Figma menu bar design in the repo; it was untracked and existed on one machine only.
- Records the directed layout revision and plans the SwiftUI port.
- No behaviour changes — the menu bar is untouched.

## Problem and root cause

**Symptom — the design existed nowhere durable.** `High-fidelity macOS menu UI v6 agent view update/` is **untracked in git** (not ignored — never added). A fresh clone, a reset, or an errant delete would have lost the only copy.
**Cause:** the export was dropped into the working tree as a scratch reference and never brought under version control.

**Second problem — the menu is single-provider.** `QuotaMenuView` renders Codex content directly with no notion of a provider, and the menu bar label shows one number. With Claude live (PR 1), there is no surface for it.

## Scope and non-goals

**Included:**
- `docs/design/menu-bar-popover/reference/` — the 473-line `MenuBarDropdown.tsx` verbatim plus the three provider marks.
- `SPEC.md` — tokens, structure, states, and six issues not to port verbatim.
- `2026-07-22-menu-bar-popover-figma-port.md` — the port plan, superseding the earlier multi-provider plan.

**Not included:**
- Any implementation. `MenuBarExtra` still uses the default `.menu` style.
- Desktop widget and watch complication, also present in the export.

## Design and ownership

`docs/design/menu-bar-popover/SPEC.md` is the authoritative target; `reference/MenuBarDropdown.tsx` holds the original export. **Where they disagree, SPEC §3 wins** — the export contains the pre-revision layout.

The revision removes the header "Refresh Now" pill (duplicate; the action remains in the bottom menu), the entire primary quota card, and the entire freshness metadata card; moves the status pill to the header's right slot; and replaces the generic gradient glyph with the active provider's own mark.

## Privacy, compatibility, and migration

Not applicable — documentation and design assets only. The added SVGs are UI marks with no data implications.

## Regression proof

Not applicable — no behaviour changes. The 168-test suite is unchanged from PR 1 and confirms nothing regressed.

## Verification

| Check | State | Result |
|---|---|---|
| `swift test` | Run | 168 passed, 0 failures (unchanged from PR 1) |
| Design assets present on branch | Run | `SPEC.md`, `MenuBarDropdown.tsx`, 3 SVGs |
| **Visual acceptance** | **Not applicable** | No UI changes in this PR |

## Risks, rollback, and limitations

**Risk:** low — no shipped behaviour changes. The forward risk is in the *plan*: `MenuBarExtra`'s default `.menu` style cannot render this design, so the port requires `.window`, which loses native dismissal, keyboard traversal, and standard metrics. The plan opens with a spike gate on exactly that, because a popover that will not close is worse than the current menu.

**Rollback:** revert the branch; only documentation disappears.

**Known limitations / unrun checks:**
- Three decisions remain open in the plan (Task 5a): where the plan name goes, whether the at-a-glance figure is missed, and where provenance lives now that the metadata card is removed. The last matters for Claude, where OAuth / statusLine / cache differ in freshness and authority.
- The export's **"% used" figure is wrong** and survives the revision unfixed: `WindowCard` renders `{remaining}% used` alongside `Remaining {remaining}%`, so 61% used displays as "39% used" while the bar fills to the other value. Recorded in SPEC §5.1 as do-not-port.

## Documentation and review focus

Adds `docs/design/menu-bar-popover/` and `2026-07-22-menu-bar-popover-figma-port.md`; marks `2026-07-22-multiprovider-menubar-popover.md` superseded.

**Riskiest decision to review:** treating `docs/design/menu-bar-popover/` as the source of truth rather than the untracked Figma folder. If the design is re-exported, the SPEC must be updated deliberately — it will not follow automatically.
