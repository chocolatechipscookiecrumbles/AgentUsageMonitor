# PR 3 — Menu bar popover: design preservation and port plan

**Branch:** `feature/menu-bar-popover-update` → `main`
**Merge after:** PR 1. Docs only — no production code changes.

## What this does

Preserves the v6 Figma menu bar design and plans its port. **No behavior changes** — the menu is untouched.

## Why it matters now

The Figma export folder was **untracked in git**. It existed on one machine only; a fresh clone or an errant delete would have lost it. `docs/design/menu-bar-popover/` is now the durable copy: the 473-line source verbatim, the three provider marks, and a `SPEC.md` extracting tokens and structure so the design is usable **without running the React app**.

## Layout revision recorded

Directed revision of the export: removes the header "Refresh Now" pill (duplicate — the action stays in the bottom menu), the entire primary quota card, and the entire freshness metadata card; moves the status pill into the header's right slot; replaces the generic gradient glyph with the active provider's own mark.

Three consequences are recorded as an unresolved gate rather than glossed: the plan name loses its only home, the at-a-glance "lowest remaining" figure disappears, and provenance is no longer shown — which matters for Claude, where OAuth / statusLine / cache differ in freshness and authority.

## Defects flagged — do not port verbatim

1. **The "% used" figure is wrong.** `WindowCard` renders `{remaining}% used` alongside `Remaining {remaining}%`, so 61% used displays as "39% used" while the bar fills to the other value. Survives the revision unfixed.
2. A `copilot` tab whose capability gate has not passed.
3. Codex-only branding and credits shown on every tab.
4. No sign-in state anywhere in the design.

## The blocker the plan opens with

`MenuBarExtra`'s default `.menu` style **cannot** render this design — `.window` is required, and that loses native dismissal, keyboard traversal, and standard metrics. The plan opens with a spike gate on exactly that, because a popover that will not close is worse than the plain menu we have.

## Testing

168 tests green (unchanged — docs only).
