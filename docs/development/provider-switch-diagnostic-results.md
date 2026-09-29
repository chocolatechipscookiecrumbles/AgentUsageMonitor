# Provider-Switch Diagnostic Results

Date: 2026-07-24

Branch: `feature/multiprovider-menubar-popover`

Diagnostic commit: `78fc077 Add provider switch diagnostic tracing`

## Audit boundary

- Built the signed app with `CodexUsageMonitor/Scripts/build-app.sh`.
- Preserved the pre-existing `CodexUsageMonitor` process at PID `74869`.
- Launched the audit-owned signed process at PID `77634` with
  `--provider-switch-diagnostic`.
- The diagnostic argument suppressed provider startup reads, refresh work, and
  Keychain access. Both surfaces were exercised in their passive unavailable
  states.
- macOS Accessibility exposed the audit process and its controls. Settings
  destinations and provider controls were resolved from their accessibility
  hierarchy rather than guessed screen coordinates.
- Temporary 15-second display recordings were captured with `screencapture`.
  Ten-frame-per-second contact sheets were generated only for inspection and
  were not added to the repository.

## Are the two tab systems the same?

No. They are separate custom selectors with separate selection owners:

| Boundary | Settings Agents | Menu-bar popover |
|---|---|---|
| Selector | `AgentSettingsTabStrip` | `MenuProviderTabStrip` |
| Selector layout | `ViewThatFits`; fitting `HStack` in the reproduced width | equal-width `HStack` |
| Selection owner | `SettingsView.selectedSettingsAgent` | `MenuBarPopoverView.selectedProvider` |
| Content replacement | `AgentsSettingsView` enum switch | `MenuBarPopoverView.providerContent` enum switch |
| Content host | `SettingsPage` and its `ScrollView` in a fixed Settings Page | intrinsic-height `MenuBarExtra(.window)` |
| Shared dependency | `QuotaViewModel` | `QuotaViewModel` |

They share a pattern, not a component: a custom button writes a provider binding
and an enum switch replaces the visible provider subtree.

## Settings Agents result

### Minimal red scenario

- Signed app, Dark appearance.
- Settings Agents destination.
- Context Rail hidden.
- The two provider tabs fit in the first `ViewThatFits` branch; the horizontal
  overflow `ScrollView` was not active.
- Passive unavailable/checking state.
- Twenty alternating accessibility presses with 120 ms between presses.

The capture is red. Stable frames precede the loop, then the recording contains
duplicated and horizontally displaced page fragments from approximately
5.60–7.10 seconds before returning to stable frames. This reproduces the
reported transient page movement without a provider read or refresh.

| Transition sample | Action → selection | Selection → content | Captured result | Verdict |
|---|---:|---:|---|---|
| Codex → Claude, first | 22.880 ms | 0.042 ms | displaced/duplicated frames in loop | Red |
| Claude → Codex, first | 18.187 ms | 0.034 ms | displaced/duplicated frames in loop | Red |
| Codex → Claude, representative | 16.351 ms | 0.028 ms | displaced/duplicated frames in loop | Red |
| Claude → Codex, representative | 17.195 ms | 0.028 ms | displaced/duplicated frames in loop | Red |

Across the recorded pointer loop:

- 20/20 button actions produced a selection change.
- 20/20 selection changes produced the matching content appearance.
- action-to-selection ranged from approximately 16–23 ms;
- selection-to-content was effectively immediate in the trace;
- no ignored click or temporarily stuck binding was observed.

Additional checks:

- Context Rail visible: 20/20 pointer transitions delivered; the Settings Page
  width remained in the fitting tab-strip branch.
- Focused left/right keyboard loop: 20/20 selection changes delivered and each
  produced matching content appearance. Keyboard movement writes the binding
  directly, so it intentionally has no `buttonAction` trace.

The first divergent boundary is after SwiftUI has changed selection and
constructed the new provider content. Event delivery is not the first failure.

## Menu popover result

### Minimal traced scenario

- Signed app, Dark appearance.
- Production 340-point-wide, non-scrolling popover.
- Passive unavailable/checking state.
- Twenty alternating accessibility presses with 120 ms between presses,
  without intentionally closing the popover.

| Transition sample | Action → selection | Selection → content | Content → resize | Host frame | Verdict |
|---|---:|---:|---:|---|---|
| Codex → Claude, first | 11.630 ms | 0.590 ms | 6.594 ms | `340 × 444` | Resize confirmed |
| Claude → Codex, first | 6.223 ms | 0.465 ms | 5.297 ms | `340 × 380` | Resize confirmed |
| Codex → Claude, representative | 7.287 ms | 0.375 ms | 4.836 ms | `340 × 444` | Resize confirmed |
| Claude → Codex, representative | 5.811 ms | 0.456 ms | 5.168 ms | `340 × 380` | Resize confirmed |

Every observed provider transition produced exactly one matching host resize:

- Codex: `{{913, 563}, {340, 380}}`
- Claude: `{{913, 499}, {340, 444}}`

The top edge remains anchored while the bottom edge moves by 64 points. Across
the pointer and focused Return-key loops:

- 20/20 actions produced a selection change in each loop;
- selection and content replacement were immediate;
- no ignored click or temporarily stuck binding was observed.

The display recorder did not reliably retain the transient `MenuBarExtra`
panel in long captures opened or exercised through Accessibility. A direct
signed-app screenshot confirms the final popover, but the menu artifact cannot
yet be timestamp-aligned to a recorded frame without a user-operated recording.
The host resize boundary is therefore confirmed; its visual causality remains a
high-confidence hypothesis rather than a completed root-cause finding.

## What was falsified

1. **One shared tab component**
   - Falsified by source inspection. The two surfaces use separate selectors,
     owners, and hosts.
2. **Missed pointer action as the first failure**
   - Falsified in the exercised loops. Every action had one matching selection
     change.
3. **Main-actor blockage before content construction**
   - Not supported. Selection-to-content was sub-millisecond in both surfaces.
4. **Settings `ViewThatFits` changing branches**
   - Falsified for the minimal red Settings scenario. The two tabs fit and the
     overflow branch was not active.
5. **Provider refresh as a prerequisite**
   - Falsified for Settings. The red capture occurred with startup monitoring
     suppressed.

## Ranked hypotheses at the user checkpoint

### Settings Agents

1. **SwiftUI/AppKit subtree compositing during enum-branch replacement**
   - Highest confidence.
   - Prediction matched: selection and content traces are immediate while
     captured frames contain displaced/duplicated hierarchy fragments.
2. **`SettingsPage` scroll-host replacement amplifies the compositor defect**
   - Falsified by a closer source-boundary review.
   - `AgentsSettingsView` owns one `AgentSettingsPageTemplate` and one
     `SettingsPage`; only the provider content inside that stable scroll host is
     replaced. The remaining geometry variable is the switched content's
     document-height envelope inside the scroll host.
3. **Hit testing or main-actor delay**
   - Low confidence after the trace.

### Menu-bar popover

1. **Intrinsic-height host resize combined with provider subtree replacement**
   - Highest confidence.
   - Every switch replaces content and resizes the private host by 64 points
     approximately 5–7 ms after content appearance.
2. **Subtree compositing independent of height**
   - Medium confidence.
   - Must be separated by an equal-height prototype.
3. **Hit testing or main-actor delay**
   - Low confidence after the pointer and keyboard traces.

## Next controlled prototypes

Do not select production code from this list until the user checkpoint is
accepted.

1. Settings Agents: retain the current fitting tab strip, shared
   `SettingsPage`, and vertical scrolling. First give only the provider-content
   envelope a viewport-filling minimum height; if that remains red, revert it
   before comparing a retained-child or native/AppKit selection container.
2. Menu: the first equal-height prototype was accepted; do not stack another
   container experiment on it.
3. Rebuild the signed app and replay the exact minimal loop after each isolated
   prototype. Revert each losing prototype before testing the next.
4. Do not use destination/provider `.id`, disabled-animation transactions,
   delayed writes, artificial sleeps, or window recreation.

## Current limitation

Global Settings destination switching is a separate deferred boundary. The
Settings Agents defect itself is resolved (see the resolution note below).

## Accepted menu result and deferred scope

The first menu prototype added a 207-point minimum height to the shared
provider-content slot, outside the enum switch. In a signed diagnostic build:

- the host produced one initial `340 × 446` frame and no resize event during
  20 alternating provider switches;
- all 20 button actions produced immediate selection and content events;
- the popover remained 340 points wide and non-scrolling;
- direct screenshots showed no clipping; the shorter Codex passive state
  intentionally leaves unused space above the footer.

The user visually accepted this tradeoff and confirmed that both the stuck
switch behavior and duplicated/displaced content were gone. This establishes
stable intrinsic host geometry as the menu root cause and winning fix.

A subsequent live-data screenshot showed that the original 207-point floor was
only sufficient for passive states. Confirmed Codex content and cached Claude
content extended beyond the proposed slot while the footer was laid out after
the 207-point envelope, producing visible overlap. The follow-up prototype:

- raises the shared normal-state floor to 288 points, covering the taller
  measured cached Claude state;
- makes provider content report its natural vertical size so exceptional
  longer states grow instead of drawing beneath the footer;
- leaves the 340-point width, non-scrolling behavior, selection model, and tab
  hit-testing code unchanged.

## Resolution — 2026-07-24

The provider-switch instability is **fixed and visually confirmed** on both
surfaces:

- **Menu popover:** the shared 288-point content floor (with provider content
  reporting its natural vertical size so longer states grow instead of drawing
  beneath the footer) is accepted. The stuck switch and duplicated/displaced
  content are gone.
- **Settings Agents:** the viewport-filling provider-content envelope inside the
  shared `SettingsPage` is accepted; Codex/Claude pointer and keyboard switching
  no longer produces duplicated/displaced frames, and scrolling, focus, and
  accessibility are preserved.

Stable intrinsic host geometry is the confirmed root cause and fix for both.

### Superseded menu geometry — 2026-07-26

Direct user feedback rejected the menu's resulting fixed-height visual treatment:
shorter provider content left a large empty region above the footer. The shared
288-point menu floor is therefore removed by explicit direction, while the
Settings Agents envelope remains unchanged. The menu now uses each provider's
natural content height and one shared 12-point content-to-footer gap.

This supersedes the menu portion of the accepted equal-height resolution above.
Because the private `MenuBarExtra(.window)` host will resize on provider
selection again, repeated signed-app pointer and keyboard switching is required
to determine whether the historical duplicated/displaced-content symptom
returns. Source builds and automated tests cannot prove that compositing
boundary.

Signed-app evidence from the requested replacement:

- Claude live content: `340 × 465` points.
- Codex live content with the credit card present: `340 × 514` points.
- Fourteen consecutive Accessibility-driven transitions alternated exactly
  between those two sizes with no clipping, overlap, ignored selection, or
  crash.

The duplicate audit instance's status item was parked in macOS's offscreen menu
bar overflow and its private popover dismissed before transition 15. Therefore
this run does not close the historical 20-cycle visual-compositing boundary;
keyboard, VoiceOver, and Light/Dark loops also remain unobserved. The layout
change is visually confirmed for the two live final states, while extended
selection-host acceptance remains limited by the hidden duplicate-instance
audit setup.

The separately tracked too-small provider-tab **hit area** was then corrected
under [its own plan](../superpowers/plans/2026-07-24-provider-tab-hit-area.md):
`MenuProviderTabStrip` moves its fill frame and `contentShape` inside the button
label, and `AgentSettingsTabStrip` adds `.contentShape(.rect)` to its fixed-size
label. That is a hit-testing change only and does not touch the accepted
geometry above.

### Live follow-up — 2026-09-27

Computer use attached to the already running signed build and switched the open
popover between Codex and Claude 20 times. Every settled selection matched the
requested provider after the first diff-only accessibility observation; a
separate four-switch loop using full accessibility snapshots confirmed 4/4.
The rendered window alternated between **340 × 859 pt** for Codex (including its
credit card) and **340 × 762 pt** for Claude. The 97-point host resize on every
switch is therefore reproducible in the current live state. The user also
reports a brief layered-background jump during the switch. Computer-use
screenshots captured settled frames, not the intermediate 60 fps frames needed
to locate that compositor boundary. No new fix or complete visual acceptance
is claimed from this loop.

By user direction, the following work remains deferred:

- the global Settings destination-switch compositor defect.

The remaining open visual track is the menu-popover corner artifact, which keeps
its own diagnosis plan and has no claimed fix.

### Fixed-height menu follow-up — 2026-09-27

The user accepted the 97-point spare region on Claude and requested a hard
screen-height limit. The provider area now sits in a vertical scroll view
between the fixed selector and footer. The outer popover is 340 × 860 points
on the observed display and caps its height to the smallest available screen
height. In the signed app, 20 alternating pointer selections all displayed the
requested provider, and every settled screenshot measured 340 × 860 points.
Codex content and the footer remained visible; Claude showed the expected
spare region. These settled screenshots establish stable host height, but do
not prove the intermediate layered frame is absent. A short display, keyboard,
VoiceOver, and Light/Dark transitions were not exercised in this follow-up.

The separate global Settings destination-switch defect remains deferred.

### User correction — 2026-09-27

The fixed-height screenshot exposed a blank region below Claude's source line;
this was caused by the 860-point menu fix, not by Claude content. The Codex
credit card also extended below the initial viewport and required scrolling.
The user rejected the blank region and requested Claude's orange warning text
match Codex's caption font. The revision changes the fixed height to a
content-fitting maximum, retains overflow scrolling, and makes both warning
strips `.caption.weight(.medium)`. In the reopened signed app, Claude's
cached-warning state measured **340 × 820 pt** with the footer directly below
the source line; confirmed Codex measured **340 × 859 pt**. Twenty alternating
pointer switches selected the intended tab and returned the corresponding
height every time. Settled screenshots showed no duplicated content, but did
not capture intermediate frames, so the brief compositor artifact remains an
unverified boundary. The small-screen cap and overflow scroll were not
directly exercised.

### Stable transparent host — 2026-09-27

The user confirmed the 39-point intrinsic host resize still caused the
doubled-background/text jump. The next signed build held the transparent
AppKit host at 340 × 860 points while keeping the visible rounded SwiftUI shell
at each provider's natural height. An initial prototype let the host's height
proposal stretch the shell; adding `.fixedSize(horizontal: false, vertical:
true)` to the shell removed that interior gap. The signed Claude screenshot
showed the footer directly below its source line and the shell ending above
the transparent host tail. Twenty alternating pointer selections all selected
the intended provider and all host screenshots remained 340 × 860 points.
The transparent tail initially swallowed clicks, so the final revision adds a
tap-to-dismiss area there. In the final signed build, clicking the transparent
tail dismissed the menu while the Agent Monitor process remained running.
Intermediate frame capture, short-screen overflow, keyboard, VoiceOver, and
Light/Dark coverage remain unverified.

### Native host mask follow-up — 2026-09-27

The fixed native host still painted a second background strip below Claude's
shorter SwiftUI panel. A signed build now measures the visible panel and masks
the host's drawing to that height while leaving the 340 × 860-point host stable.
The Claude screenshot showed the second painted strip removed; clicking the
masked tail dismissed the menu and left the app running. The masked tail is
still part of the native window's hit area, so clicks there do not pass through
to the underlying app. The user confirmed provider switching is fine in this
build and asked to stop. A bottom rounded edge remains visible and is recorded
as the outstanding visual detail. No further UI change was made.

### Failure-state viewport regression — 2026-09-28

A focused native NSHostingView/NSScrollView regression reproduced the reported
header/footer overlap using the existing modifier order. An 800-point content
region inside a 637-point maximum-height allocation produced an actual 800-point
scroll viewport at y=4.5…804.5, instead of y=86…723. The outer frame constrained
allocation while the vertically fixed scroll view kept its ideal height.

The shared MenuAdaptiveLayout now measures intrinsic content and fixed regions,
then assigns the bounded height to the scroll view itself. The same test passes,
with content taller than the native viewport and the viewport between the header
and footer. This proves the viewport geometry correction, not the absence of
intermediate compositor artifacts in the real MenuBarExtra.

Custom-panel and native-popover comparison apps use this layout and shared
production card renderers. They have not replaced the production host. Computer
Use timed out (-10005) when opening the signed Panel Demo; its resulting audit
process was closed without touching the pre-existing app. Pointer/keyboard,
VoiceOver, Light/Dark, multi-screen and intermediate-frame acceptance remain
pending. The trial build and full source-check results are recorded in the
[active plan](../superpowers/plans/2026-09-27-adaptive-menu-presentation.md).

### Trial rejection and diagnosis — 2026-09-28

The user reported that neither comparison host fixed the defect and that both
recreated the switch-tab artifact. Both trials were built to "resize to content
immediately" with no transparent tail, which reintroduced the host resize that
the July diagnosis had identified as the cause and that both accepted fixes
removed.

The resize could not be immediate. A switch commits the new SwiftUI subtree,
measures it through a preference, and resizes the window on a later run-loop
turn. In between, the unanchored, vertically fixed root is centered in the
old-sized window, so the tabs and header move by half the height difference
and the window then snaps them back. A local headless probe (not committed)
reproduced this in a trial-like `NSPanel` hosting the same geometry: after a
520 → 380 pt content switch, the viewport started at y=156 instead of y=86
until the deferred resize, and anchoring the root to the top removed the
displacement. The same probe showed that `MenuAdaptiveLayout` settles in one
layout pass inside a fixed host, so it was ruled out as the cause.

The user then confirmed that tab switching works in the production build: the
stable 860-point host together with the bounded viewport. The trial code is
archived outside this branch. An app-owned, content-fitted panel remains
possible only with a top-anchored root and a window that is never smaller than
its committed content; see the
[content-fitted menu panel plan](../superpowers/plans/2026-09-29-content-fitted-menu-panel.md).
