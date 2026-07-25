# PR 4 — Prototype finalization: popover sizing, provider selector, per-agent notifications

**Branch:** `feature/prototype-finalization` → `main` · Branch-scoped (Workstreams A, C, D, E, G + this session's three head commits)

## Summary

- Brings the multi-provider (Codex + Claude) menu-bar app from prototype to a finalizable state: root README, standardized Connect/Disconnect, popover first-run auth, per-agent quota warnings with real per-agent notifications, and one shared refresh cadence (Workstreams A, C, D, E, G; B implemented separately as the bar modes).
- Fixes a menu-bar popover layout bug: the popover now grows to fit its content instead of drawing the footer over a taller state (e.g. the Claude connection-recovery card).
- Adds a smart menu-bar provider selector so the single-provider "5-hour and weekly" style can show Codex *or* Claude, appearing only when more than one provider is connected.

## Problem and root cause

**Popover overflow (symptom):** with the Claude tab in a failed-connection state, the recovery card rendered *under* the footer rows. **Cause:** `MenuBarExtra(.window)` only re-measures its intrinsic height on discrete events (a tab switch), not when a conditional row appears in place, so the host window kept its previous, too-short height. **Evidence:** direct screenshot of the overlap; confirmed against the accepted 288pt-floor geometry in `docs/development/provider-switch-diagnostic-results.md` (host resizes on tab switch but not on in-place growth).

**Provider selector (symptom):** the text style was hard-wired to Codex, so a Claude-only user saw Codex data (or dashes). **Cause:** `MenuBarLabelPresentation` read only `displayState` (Codex). **Evidence:** source inspection of the label path.

**Finalization workstreams:** each is grounded in `docs/superpowers/plans/2026-07-24-prototype-finalization.md` (owners, decisions, and per-step evidence).

## Scope and non-goals

**Included:**
- Root `README.md` (A); standardized `AgentDisconnectButton` + app-local Codex disconnect (C); popover first-run auth confirmed via existing unavailable cards (D); per-provider quota thresholds + real Codex **and** Claude notification delivery (E); shared `refreshMode` cadence with a Claude network floor + `User-Agent` rate-safety fix (G).
- Popover grows to fit content (top-anchored, width unchanged, guarded no-op for equal-height states).
- Smart provider selector for single-provider menu-bar styles; new persisted `menuBarProvider`; `MenuBarDisplayStyle.isSingleProvider`.
- `docs/development/notification-warnings.md` documenting the five "Other Warnings".

**Not included:**
- The both-providers-at-once menu-bar readout (B) beyond the already-shipped bar modes — deferred by user direction.
- App icon artwork (F) — pending user-supplied art.
- Global Settings destination-switch compositor defect and the popover corner-artifact track — separately deferred.
- Extending the five Codex "Other Warnings" to Claude — documented as current scope, not a fix here.

## Design and ownership

- **State/owners unchanged:** `QuotaViewModel` (state), `QuotaMonitor`/`ClaudeUsageMonitor` (read cycles), `QuotaNotifier`+`NotificationPolicy` (delivery), `AppSettings` (persistence). No new global owner.
- **Popover sizing:** `MenuPopoverChrome` measures the shell height via a `PreferenceKey`; `MenuPopoverWindowConfigurator` resizes the host to it. Content height is intrinsic, so there is no measure→resize feedback loop.
- **Provider selection:** new pure `MenuBarProviderSelection` owns eligibility ("connected" = has a usable `MenuProviderSummary` reading), effective-provider resolution, and selector visibility. `QuotaViewModel` exposes `menuBarEligibleProviders`/`effectiveMenuBarProvider`; the label and settings consume them.

## Privacy, compatibility, and migration

- **Privacy:** unchanged. Claude path stays within the accepted personal-build boundary (Claude Code Keychain credential → statusLine → cache); no new outbound path. G adds the `User-Agent: claude-code/<version>` header to the existing OAuth read and obeys `Retry-After`.
- **Migration:** E migrates the old global quota-threshold set into the per-provider store (both migration paths tested). The new `menuBar.provider` key defaults to Codex; absent keys fall back to prior defaults.
- **Compatibility:** macOS 14+, Swift 6.2; no schema breaks.

## Regression proof

- **Claude quota alert repeating every refresh** → now fires once per crossed enabled threshold; `QuotaThresholdEvaluatorTests` (Codex legacy vs Claude-namespaced dedup keys, real-zero vs missing window).
- **Chips not reflecting on/off** → container observes `AppSettings` so a tap re-renders; covered by settings/threshold tests.
- **Provider-selector correctness** → `MenuBarProviderSelectionTests`: single-provider fallback, stored-choice-wins-when-connected, selector hidden below two providers.
- **Popover overflow** → no deterministic unit test (private `MenuBarExtra(.window)` compositing); it is signed-app acceptance under the branch GUI waiver.

## Verification

| Check | State | Result |
|---|---|---|
| `swift build` | Run | Build complete, no warnings |
| `swift test` (full suite) | Run | 287 tests, 0 failures |
| `MenuBarProviderSelectionTests` | Run | 9/9 pass |
| Popover grows to fit content (signed app) | Not run | Unobserved — branch GUI waiver |
| Provider selector + menu-bar glyph (signed app) | Not run | Unobserved — branch GUI waiver |
| Per-agent notification delivery (signed app) | Not run | Unobserved — notifier is `.app`-gated |

Compilation is not visual acceptance; the signed-app menu/notification/appearance checks are recorded as Not run under the documented waiver.

## Risks, rollback, and limitations

**Risk:** the popover host resize sets the window frame directly; a wrong measurement could jitter the popover. Mitigated by the >0.5pt guard (equal-height states are a no-op) and top-anchored, width-preserving frame math.

**Rollback:** revert the three head commits (`Grow the menu-bar popover…`, `Add a smart provider selector…`, `Document the notification…`) independently; each is self-contained. The finalization workstreams (A–G) are individually revertible earlier commits.

**Known limitations / unrun checks:** all signed-app visual/keyboard/VoiceOver acceptance is unobserved under the branch waiver; the five "Other Warnings" deliver Codex-only events today; app icon (F) is pending artwork.

## Documentation and review focus

- Plans/docs: `docs/superpowers/plans/2026-07-24-prototype-finalization.md`, `docs/development/notification-warnings.md` (new), `docs/development/claude-usage-endpoint-rate-safety.md`, `docs/development/provider-switch-diagnostic-results.md`, root `README.md`.
- **Riskiest decision to review:** the popover host-resize in `MenuPopoverWindowConfigurator` — confirm it does not reintroduce a resize on plain tab switches (the documented invariant), and the "connected" definition in `MenuBarProviderSelection` (data-availability as the eligibility signal).
