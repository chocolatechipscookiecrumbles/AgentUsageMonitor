# PR 11 — App icon, plan name in the popover header, and version 1.0.0

**Branch:** `feature/app-icon-and-plan-name` → `feature/token-monitor-day-week` · 3 commits, 32 files
**Compare:** historical private-repository comparison (branch not published)
**Stack:** 7 of 10 — merge after PR 10.
**State: Draft** — the Codex plan header has never been seen against a live account.

> **Note on the version.** This PR sets `1.0.0`. **PR 13 revises it to `0.0.1`.**
> The intermediate state is preserved rather than rewritten, so the reasoning for
> both decisions stays visible in history.

## Summary

- Ships a real app icon: `AppIcon.appiconset` with all ten macOS representations,
  and a bundle `.icns` built by `iconutil` from those same PNGs.
- The popover's provider header now names the account's **plan** — Pro, Plus,
  Max 20x — instead of repeating the provider name the tab already shows.
- Sets the version and build number, and brings the release guide up to date.

## Problem and root cause

**1. No app icon.** The app shipped with the generic placeholder. Because it is
`LSUIElement`, Finder, Get Info, and notification banners are the *only* places an
icon is ever seen — which is exactly why it was easy to miss.

*A second-order cause worth recording:* `actool`'s convenience `.icns` carries only
four sizes, which left Get Info upscaling a 256 and looking soft. The fix builds the
`.icns` from the appiconset PNGs with `iconutil` instead, and the build now **fails**
if the result is missing or empty.

**2. The header was redundant.** It showed the provider name — directly below a tab
that already said the same word. One of the two most valuable lines in the popover
carried no information.

## Scope and non-goals

**Included:** the icon set and `.icns` build step, `AgentPlanName` as one formatter,
`MenuProviderHeaderPresentation`, and version/build in `Info.plist`.

**Not included:** the product rename (PR 13), and any other popover layout change.

## Design and ownership

**One `AgentPlanName` formatter** serves the popover header, both agent pages, the
context rail, and Diagnostics, so the same account cannot be named differently on
two surfaces.

Plan resolution reads the **connected account first** and the usage record's plan
hint second. An unknown plan falls back to the provider name rather than to a blank
line.

The plan **survives refreshing and unavailable states**, because it is account
identity — not a property of the reading currently in flight. A header that blanked
during a refresh would flicker on every cycle.

## Privacy, compatibility, and migration

**Privacy.** The plan name is account metadata already present in the quota
response. No new read, field, or request.

**Compatibility.** Plan identifiers come from the providers and can change. An
unrecognized identifier degrades to the provider name rather than showing a raw
string.

**Migration.** Not applicable.

## Regression proof

No prior failure to reproduce — this is an icon and a header change, so per the
repository's testing policy no automated coverage is added beyond the plan-name
formatter's own resolution-order cases.

The icon has a **build-time** guard instead of a test: `build-app.sh` fails if the
`.icns` is missing or empty, and the guide documents a `iconutil -c iconset`
spot-check expecting ten entries.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` at this branch tip | Run | Build complete |
| `swift test` at this branch tip | Run | 316 tests, 0 failures |
| `.icns` contains ten representations | Run | `iconutil -c iconset` then count → 10 |
| `plutil -extract CFBundleIconFile` | Run | `AppIcon` |
| Plan name in the Claude popover header | Observed | Renders and survives refresh |
| Plan name against a **live Codex** account | **Not run** | Only the Claude header has been seen. The resolution order is shared, but the Codex plan identifiers are not confirmed against a real response |
| Icon in Finder, Get Info, and a notification banner | **Not run** | |

## Risks, rollback, and limitations

**Risk.** An unrecognized Codex plan identifier falls back to the provider name —
the old behavior — so the failure mode is a lost improvement, not a wrong plan
shown. That is the intended degradation.

**Rollback.** Revert. The icon reverts to the placeholder; the header reverts to the
provider name.

**Limitation.** Version `1.0.0` set here is superseded by PR 13.

## Documentation and review focus

Changed: `docs/development/releasing-on-github.md`, the planning board, `CONTEXT.md`.

Focus on **plan resolution order** — whether a stale cached account can name a plan
the current account no longer has.
