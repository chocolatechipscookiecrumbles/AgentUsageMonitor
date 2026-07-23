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
   - Medium confidence.
   - Each provider branch constructs a new `SettingsPage` and `ScrollView`.
     Stable-child retention or a native selection container can falsify this.
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

1. Settings: retain the current fitting tab strip and compare only the content
   container, in this order:
   - native `TabView(selection:)`;
   - stable host retaining both provider children;
   - AppKit `NSTabViewController` adapter only if both SwiftUI variants remain
     red.
2. Menu:
   - first equalize the two provider content height envelopes while preserving
     the existing switch, to isolate host resize from subtree replacement;
   - then compare native `TabView(selection:)`;
   - then a stable retained-child host;
   - use an AppKit child-controller host only if the SwiftUI variants remain
     red.
3. Rebuild the signed app and replay the exact minimal loop after each isolated
   prototype. Revert each losing prototype before testing the next.
4. Do not use destination/provider `.id`, disabled-animation transactions,
   delayed writes, artificial sleeps, or window recreation.

## Current limitation

The Settings defect is red-capable and ready for controlled prototypes. The
menu event/selection/resize loop is deterministic, but final proof that the
reported menu artifact aligns with the resize still needs a user-operated
recording or another capture path that reliably includes the tracked
`MenuBarExtra` panel.
