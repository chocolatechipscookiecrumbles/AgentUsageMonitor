# Content-Fitted Menu Panel Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking. This is a prototype-gated architecture change. The current production menu (stable 860-point transparent `MenuBarExtra` host + `MenuAdaptiveLayout`) was confirmed by the user on 2026-09-28 and remains the default until this plan's acceptance gate passes. Do not promote anything on the strength of tests, source review or settled screenshots. The type-level design is in [the code structure draft](2026-09-29-content-fitted-menu-panel-structure.md).

**Goal:** Replace the stable transparent host with an app-owned window that fits the visible menu exactly: no transparent tail, no second painted layer, no clicks swallowed below the menu. Switching tabs and refreshing must not bring back the duplicated or displaced frame.

**Architecture:** A non-activating `NSPanel` owned by `MenuPanelController` and anchored under an owned `NSStatusItem`. It hosts one top-anchored `MenuSurface`, which renders only snapshots that the controller publishes. Every content change (tab click, refresh, settings or enrollment change) goes through one pipeline:
1. build the next snapshot;
2. pre-measure it offscreen;
3. grow the window if needed, *before* publishing;
4. publish;
5. shrink the window only after the live surface settles.

The window is therefore never smaller than the committed content. Intermediate frames are either exact or show invisible transparent slack below a top-anchored shell. The design does not rely on AppKit and SwiftUI committing in the same frame.

**Tech Stack:** Swift 6.2, SwiftUI + AppKit for macOS 14+, Swift Package Manager, existing signed-app scripts.

## Current production limitation (user, 2026-09-29)

The stable-host build no longer shows the switch artifact, but the 860-point transparent host still reads as a leftover dropdown: an outlined, shadowed region continues below the visible menu to the host's full height. Removing that tail is this plan's goal; no interim fix is planned.

## Starting material

The rejected trial code is archived on the local branch `archive/rejected-menu-trials-2026-09-28` and is not part of this branch or `main`. Task 3 restores only what this plan reuses: `MenuContentSnapshot`, `MenuStatusHostingView`, the `MenuTrialSurface` body (as `MenuSurface`), the status-item and dismissal code in `MenuPresentationController` (as `MenuPanelController`) and `build-menu-trials.sh`. Task 2's anchor test is first run against the archived `MenuTrialShell` to show red.

## Decisions (user, 2026-09-29)

| Topic | Decision |
|---|---|
| Root view | One snapshot-fed `MenuSurface` for live and fixture data |
| Tab-click grow target | Pre-measure the target snapshot offscreen; grow to `max(current, target)` |
| Refresh-driven changes | The controller gates snapshots through the same pipeline as tab clicks |
| Pre-measure too small | Grow late at settle; `os_log` fault in debug builds with both heights |
| Activation | `.nonactivatingPanel`; the frontmost app keeps focus |
| Open/close | About a 0.1 s alpha fade (opacity only) |
| Outside click | Close and pass the click through |
| Keyboard | Focus + Return only; no new shortcuts |
| Settings | Main-menu ⌘, dispatch |
| After promotion | Keep the `MenuBarExtra` kill switch and the fixture demo; delete the popover trial and the window-popover gate |
| PR scope | PR 1: prototype behind a flag, production unchanged. PR 2: promotion after acceptance |
| Commit base | Commit the pending Claude work first, as its own reviewed commits |

## Why this is expected to work where the 2026-09-28 trials failed

The rejected Panel trial had two independent faults (see [Trial rejection and diagnosis](../../development/provider-switch-diagnostic-results.md#trial-rejection-and-diagnosis--2026-09-28)):

1. **The root was not top-anchored.** In any frame where the window height and the shell height differed, SwiftUI centered the shell. The tabs and header moved by ΔH/2 (probe: 70 pt for a 140 pt switch). Top-anchoring removed that displacement in the probe.
2. **It resized after measuring, in both directions** (`queueSize` → `DispatchQueue.main.async`). Growth therefore always showed at least one frame where the window was smaller than the shell.

The diagnosis's optional follow-up asked for the frame to be applied "in the same commit as the content". This plan swaps that for an ordering guarantee, because SwiftUI's layer commit and the window-server frame change follow separate paths and cannot be proven synchronous from public API.

**This is still not a guaranteed permanent fix.** It removes both mechanisms we have reproduced. Private AppKit/SwiftUI compositing can still misbehave, and only the recorded acceptance in Tasks 6–7 can show whether it does. If that is red, the current production host stays.

## Global constraints

- Follow AGENTS.md: native-menu dynamic-update guardrails, selection-host geometry guardrails, GUI audit command safety and build verification. Do not use `.id(selection)`, disabled-animation transactions, artificial delays, window recreation, `TimelineView` or per-second invalidation.
- 340-point width. Height is capped to the status item's screen. Only provider content scrolls, and the header, tabs and footer stay fixed. `MenuViewportLayout` (single-pass successor to `MenuAdaptiveLayout`) keeps `MenuViewportOverflowTests` green.
- Keep the current cards, charts, tabs and footer design (the user's stated preference). No traditional text menu, and no `NSPopover` chrome (rejected).
- `MenuPanelController` is the only writer of the window frame. `MenuSurface` observes only `MenuPanelModel`, never `QuotaViewModel`.
- PR 1 leaves production unchanged. The panel runs only behind `--menu-presentation=panel`, and `MenuBarPopoverView`, `MenuPopoverChrome` and `MenuPopoverWindowConfigurator` are untouched.
- Do not modify signing, entitlements, bundle identifiers, deployment target or build settings.
- Tests: only the two minimal regressions for reproduced defects (Task 2). No feature, routing or happy-path tests.

## Design invariants

| ID | Invariant | Enforced by |
|---|---|---|
| I1 | Tabs and header never move when the window height ≠ the shell height | `MenuPanelRoot` `.frame(maxHeight: .infinity, alignment: .top)`; `layerContentsPlacement = .topLeft` (Q1) |
| I2 | Window height ≥ committed content height on every frame | `MenuContentPipeline.stage`: `envelope.prepare` → `applyHeight` → `model.publish`, in one main-thread turn |
| I3 | At rest, window height == shell height (no tail) | `surfaceDidSettle` → `.shrink` on the next run-loop turn |
| I4 | A stale shrink never undercuts newer content | `MenuWindowEnvelope` generation guard (`applyShrink`) |
| I5 | No private host paints behind the shell; the shadow follows the shape | Owned clear, non-opaque `MenuPanel`; `invalidateShadow()` in `setHeight` |
| I6 | Resizing is driven only by semantic events | Selection intent, coalesced `objectWillChange`, open, screen change; never a timer |

## Open questions the prototype must answer (Task 3)

- **Q1** — When a borderless, non-opaque panel grows (origin.y decreases, height increases), does AppKit show one frame with the old backing anchored bottom-left, which would look like the content dropping? Compare `layerContentsPlacement = .topLeft` with and without `setFrame(display: true)`. Record which variant is red or green.
- **Q2** — Does `invalidateShadow()` after each frame write remove the "double layer" edge, or is a stale shadow visible for a frame?
- **Q3** — Does pre-measurement agree with the settled height across all fixture states? Every debug `lateGrow` fault is a measurement bug to fix, not to tolerate.
- **Q4** — Do focus + Return and Esc reach a `.nonactivatingPanel` while another app stays frontmost?
- **Q5** — Does the new `NSStatusItem` keep a stable menu-bar position (`autosaveName`) compared with the `MenuBarExtra` item?

## Tasks

### Task 0 — Preconditions

- [x] Review and commit the pending Claude/provider working-tree changes as their own reviewed commits (user decision). Done 2026-09-29: Claude passive-first, model identifiers, stable menu host + bounded viewport, renderer split, and these docs; the trial code was archived.
- [x] Re-inventory running `CodexUsageMonitor` processes and record the PIDs the user owns. Never terminate them. Done 2026-09-29: one user-owned instance, PID 75660 (`.build/CodexUsageMonitor.app`), left untouched.

### Task 1 — ADR 0004 (Proposed)

- [x] Write `docs/adr/0004-content-fitted-menu-panel.md`:
  - **Context:** two reproduced mechanisms (centered stale frame; resize-after-measure).
  - **Decision:** invariants I1–I6, the gated snapshot pipeline and the decisions table.
  - **Rejected alternatives:**
    - the fixed transparent host: the current accepted host, kept as the kill switch;
    - resizing `MenuBarExtra` to content: private host resize, the July root cause;
    - resize-after-measure: the 2026-09-28 trials;
    - `NSPopover`: rejected chrome;
    - growing to the screen cap: rejected in favor of pre-measuring;
    - same-commit synchronization: not provable with public API.
  - **Consequences:** loses `MenuBarExtra` scene conveniences; Settings goes through ⌘, dispatch; a new status item position.
- [x] Mark ADR 0003 `Superseded by 0004`, and record that its "resize to content immediately / no transparent tail" constraint contradicted the established root cause.

### Task 2 — Minimal red regressions (reproduced defects only)

- [x] `MenuPanelAnchorTests.testShellStaysTopAnchoredInTallerWindow`: run it first against today's `MenuTrialShell` and confirm **red** (probe: viewport y=156 vs 86). Done: red against the archived shell (viewport moved 70 pt when the window grew 140 pt).
- [x] `MenuWindowEnvelopeTests.testStaleShrinkIsDroppedAfterNewerGrow`: run it first against a policy without the generation guard and confirm **red**. Done: red against the unguarded policy (window 400 pt under 700 pt content).
- [x] Record in the Verification log that neither test proves compositor behavior.

### Task 3 — Prototype (panel mode only)

Follow the file map in the structure draft.
- [x] ~~Refactor `MenuAdaptiveLayout` into `MenuViewportLayout`~~ Changed: added `MenuViewportLayout` for the panel only, because production's `MenuBarPopoverView` uses `MenuAdaptiveLayout` and PR 1 leaves production unchanged. Promotion replaces `MenuAdaptiveLayout` and retargets `MenuViewportOverflowTests`. `MenuViewportOverflowTests` stays green.
- [x] Add `MenuPanelState`, `MenuSurfaceActions` and `MenuSurface` (moved from `MenuTrialSurface`; the tab binding routes writes to `actions.select`). Make `MenuContentSnapshot` `Equatable`. `MenuContentSnapshot` is **not** made `Equatable` (see Deviations).
- [x] Add `MenuPanelModel` and `MenuPanelRoot` (top anchor). Run the anchor test → green.
- [x] Add `MenuWindowEnvelope`. Run the envelope test → green.
- [x] Add `MenuSurfaceMeasurer`, `MenuSnapshotSource` (live and fixture) and `MenuContentPipeline`.
- [x] Add `MenuPanel`, `MenuPanelController` (non-activating, fade, monitors, `setHeight`) and `MenuCommandRouter`. Replace `MenuPresentationMode` with `MenuHost`.
- [x] Do not restore `MenuTrialView`, `MenuTrialShell`, `MenuPresentationSizing`, `MenuTrialPanel`, `MenuPresentationController` or the popover trial mode; they are superseded by the files above.
- [ ] Try the Q1 variants one at a time, each as its own signed build. Revert each losing variant before testing the next.
- [x] `swift test --filter 'MenuPanelAnchorTests|MenuWindowEnvelopeTests|MenuViewportOverflowTests'`, then `swift test` once. Report warnings precisely.

### Task 4 — Signed build

- [x] Restore `build-menu-trials.sh` from the archive branch and reduce it to Panel Live and Panel Demo. Build them, then run `codesign --verify --deep --strict` on both. Done 2026-09-29 (see Verification log).
- [x] Run `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' build`. Done 2026-09-29 from `CodexUsageMonitor/`: **BUILD SUCCEEDED**, exit 0. The adaptive-menu plan's "exit 66, no project" limitation does not apply when run from the package directory.

### Task 5 — Self-audit (the agent's own evidence only)

- [x] Attempted 2026-09-29 and blocked (see Verification log). Launch Panel Demo, which uses no live services, and check the debug log for `lateGrow` faults (Q3). If Computer Use times out, stop promptly, close only the audit-owned process and move on to Task 6.

### Task 6 — User-operated recording (the actual acceptance evidence)

- [x] The user records at 60 fps with QuickTime (done 2026-09-29; see the Verification log):
  - Panel Demo: 20 Codex↔Claude pointer switches, including the tallest Codex (credit card) and shortest Claude states; focus + Return switching; "Next state" through failure → recovery; open → immediate tab click during the fade.
  - Panel Live: 20 switches and one manual refresh.
- [ ] Step through the recordings frame by frame. Red if any frame shows tabs or header displaced, duplicated text, a second background layer, clipped footer or a stale shadow.

### Task 7 — Acceptance matrix and decision gate

- [x] Beyond Task 6, check:
  - failure-state overlap, and recovery controls reachable by scrolling;
  - Light and Dark;
  - VoiceOver;
  - clicking outside closes the menu and the click passes through, with no tail;
  - Esc, and the frontmost app keeping focus (Q4);
  - Settings and Notifications commands;
  - status item position (Q5);
  - a short screen and multiple screens.
- [x] Compare side by side with the current production host. The user decides whether to promote the panel. **If any item is red and the fix is not obvious and isolated, stop.** Production remains the stable host.
- [x] Prepare PR 1 with `preparing-evidence-rich-prs`. The user creates it.

### Task 8 — Promotion, PR 2 (only after explicit user acceptance)

- [x] Switch `MenuHost.current` to default to `.panel`, with `--menu-host=legacy` or the `MenuHostLegacy` default restoring the `MenuBarExtra` host (kill switch).
- [ ] ~~Convert~~ **Not done by decision (2026-09-30):** the kill switch keeps the exact stable-host code accepted on 2026-09-28 rather than a new, unverified path. Convert `MenuBarPopoverView` into a thin `MenuPopoverChrome { MenuSurface(live snapshot) }` wrapper, so the kill switch shares the one renderer.
- [x] Delete `WindowPopoverGateView` and `MenuPopoverViabilityGate`. Keep `--menu-fixture`.
- [x] Update AGENTS.md "SwiftUI selection-host geometry guardrails" to describe the panel invariants, with the 860-point host as the kill switch. Also update `UsageProbe/README.md`, `docs/development/operating-notes.md` and `provider-switch-diagnostic-results.md`.
- [ ] Prepare PR 2 with `preparing-evidence-rich-prs`. The user creates it.

## Risks and limitations

- Depends on AppKit's resize compositing for a non-opaque borderless window (Q1). A future macOS release could change it; the kill switch exists for that case.
- Replacing `MenuBarExtra` gives up its built-in behaviors:
  - status-item overflow handling;
  - the scene-backed `openSettings` action;
  - system dismissal semantics.
  These are reimplemented and must be accepted in the signed app.
- Pre-measurement can drift from live layout. Drift is visible only as a debug fault and at most a one-frame bottom clip; it must be fixed, not masked with a margin.

## Deviations from the structure draft (2026-09-29)

- **No `Equatable` de-duplication.** `MenuProviderHeaderPresentation`, `CodexMenuPresentation` and `ClaudeUsageDisplayModel` are not `Equatable`, and conforming them would spread into the quota model types. The pipeline instead coalesces a burst of model changes into one rebuild per run-loop turn and always publishes.
- **`MenuViewportLayout` is added beside `MenuAdaptiveLayout`,** not in place of it, so production is unchanged in PR 1. Evidence that the panel needs it: in a fresh `NSHostingView`, the archived trial shell (built on `MenuAdaptiveLayout`) reports a fitted height of 263 pt because its measured `@State` is still empty, which counts the viewport as 0. The `MenuViewportLayout`-based root reports its real height (860 pt for the capped fixture) on the first pass.
- **Display changes close the panel** instead of re-anchoring it, which keeps geometry ownership simple.
- **`MenuSurface` lives in `Menu/Panel/`,** because only the panel uses it until promotion.
- **Status item** keeps the archived default click action (mouse-up), unchanged from the trials.

## Verification log

- 2026-09-29, `MenuPanelAnchorTests` (red first). Against the archived `MenuTrialShell`: viewport minY −102.5 in a window 140 pt taller vs −172.5 in the fitted window, a 70 pt move, so red. Against `MenuPanelRoot`: minY 120 in both, so green. A first draft of the test built its window from `fittingSize` on a host with `sizingOptions = []`, which reports 0. That was corrected before accepting either result.
- 2026-09-29, `MenuWindowEnvelopeTests` (red first). The unguarded policy applied a stale shrink to 400 pt beneath 700 pt of content, so red. The generation guard makes it green.
- Neither test proves compositor behavior; that remains Tasks 6–7.
- 2026-09-29, `xcodebuild -scheme CodexUsageMonitor -destination 'platform=macOS' build` from `CodexUsageMonitor/`: exit 0, BUILD SUCCEEDED. Warnings: the three existing Keychain deprecations only.
- 2026-09-29, `swift build` and `swift test`: exit 0, 316 tests, 1 skipped (the existing glyph test), 0 failures. No new warnings; the existing Keychain deprecation warnings remain.
- 2026-09-29, signed build: `build-menu-trials.sh` run from a separate worktree at `473473a`, so the user-owned app at `.build/CodexUsageMonitor.app` (PID 75660) was not re-signed while it ran. A fresh worktree lacks the git-ignored `Resources/Assets.xcassets`; it was copied from the main checkout. Exit 0, "Signed with: Developer ID Application". `codesign --verify --deep --strict` passed for Panel Live (`MenuPresentationTrialMode=panel`, fixtures false) and Panel Demo (fixtures true). Both apps were copied to `CodexUsageMonitor/.build/Menu Presentation Trials`, replacing the rejected 09-28 builds there. Warnings: the three existing Keychain deprecations only.
- 2026-09-29, self-audit (Task 5) **blocked; no panel observation.** Panel Demo was launched as audit PID 79907 beside the user's app. System Events resolved "process whose unix id is 79907" to the user's instance, because both share the bundle identifier `com.david.codex-usage-monitor`, so the Accessibility click opened the user's production menu. That menu was closed with the same toggle, only PID 79907 was terminated, and PID 75660 kept running. Panel Demo's own status item did not appear in the visible menu bar. Screenshots taken during the attempt captured unrelated screen content and were deleted. Automated self-audit needs the user's app quit first, or a distinct bundle identifier, which AGENTS.md forbids changing. Tasks 6–7 remain the acceptance path.
- 2026-09-29, **user observation (no recording).** In the signed Panel builds, switching back and forth from every fixture stage worked, and the switch artifact did not appear. The user asked to hide the scroll bar while keeping scrolling; `2726bd6` adds `.scrollIndicators(.never)` to the panel viewport, and the signed apps were rebuilt and re-verified. There is no automated test for this presentation preference. Not yet observed: a frame-by-frame 60 fps recording, VoiceOver, Light/Dark, a short screen, multiple screens, and the Settings commands from the panel.
- 2026-09-29, **user acceptance.** The user reported that the 60 fps recording of the panel checks out, and that VoiceOver, Dark and Light appearance are fine. Still not observed: a short screen, multiple screens, and the Settings commands from the panel. The user also reported that the separate, deferred Settings destination-switch defect still occurs between General and Notifications; it is outside this plan (see `2026-07-18-settings-palette-and-refresh-preferences-presentation.md`).
- 2026-09-30, **user acceptance (Observed).** Short screen, multiple screens and Settings commands from the panel all check out. Together with the 60 fps recording, VoiceOver and Light/Dark results, Task 7 is complete; the user directed promotion.
- 2026-09-30, **promotion (PR 2).** `MenuHost.current` defaults to `.panel`; `--menu-host=legacy` or `defaults write com.david.codex-usage-monitor MenuHostLegacy -bool true` restores the `MenuBarExtra` host. The window-popover viability gate, its scene, its launch-policy argument and its one test (`testWindowPopoverGateDoesNotStartProviderMonitoring`) are removed with the feature. `swift test`: 316 tests, 1 skipped, 0 failures.
- 2026-09-30, **provider tab tint (user request).** The selected tab's text and underline use the provider's color: Codex keeps the system blue accent; Claude uses brand orange #D97757 in Dark and the darker brand shade #C15F3C in Light, for caption-size contrast. Tab text, layout and hit areas are unchanged. Signed-app check planned on the 0.1.0 release candidate.
