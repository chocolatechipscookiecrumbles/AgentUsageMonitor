# Provider-Switch Instability Diagnosis and Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce, identify, and fix the jumping content, delayed clicks, and temporarily stuck provider selection reported in both Settings Agents and the menu-bar popover.

**Architecture:** Treat Settings Agents and the menu-bar popover as two independent feedback loops that share only a selection pattern and `QuotaViewModel`. Add temporary, argument-gated monotonic tracing at the button, selection, content, and window-resize boundaries; use signed-app frame capture to identify the first divergent boundary. Prototype one container strategy at a time only after the trace establishes whether the defect is event delivery, main-actor delay, view replacement, or host compositing.

**Tech Stack:** Swift 6.2, SwiftUI for macOS 14+, AppKit window notifications, `OSLog`, XCTest where a deterministic nonvisual seam exists, Swift Package Manager, and the signed `.app`.

**Resolution — 2026-07-24:** This diagnosis is complete. The instability is fixed and visually confirmed on both surfaces via stable intrinsic host geometry (menu: shared 288-point content floor; Settings: viewport-filling provider-content envelope). The separately tracked too-small tab hit area is fixed under [the hit-area plan](2026-07-24-provider-tab-hit-area.md). The argument-gated diagnostic scaffolding this plan introduced (`ProviderSwitchTrace`, `ProviderSwitchWindowProbe`, the `--provider-switch-diagnostic` launch gate, and every `record(…)` call site) has been **removed** now that the cause is established. See [provider-switch diagnostic results](../../development/provider-switch-diagnostic-results.md#resolution--2026-07-24). Only the global Settings destination-switch defect remains deferred.

## Global Constraints

- Work on `feature/multiprovider-menubar-popover` in its existing linked worktree; do not push before explicit approval.
- Build the signed app with `CodexUsageMonitor/Scripts/build-app.sh` for every visual or interaction claim.
- Preserve `SettingsView` as owner of the Navigation Sidebar, selected Settings Destination, Settings Page, Context Rail visibility, and Settings Agent.
- Keep menu opening passive: no refresh, timer, polling loop, `TimelineView`, or per-second invalidation.
- Keep the menu popover non-scrolling and 340 points wide.
- Do not use `.id(selectedProvider)`, `.id(selectedDestination)`, disabled-animation transactions, delayed state writes, window recreation, or artificial sleeps as fixes.
- Do not assume that one fix must serve both surfaces. Split the production changes if the traces prove different causes.
- Do not add a broad feature-presence test. Add automated coverage only if the minimized defect has a deterministic seam that fails before the fix.
- Tag every temporary diagnostic log with `[DEBUG-provider-switch]`; remove every tagged line before the production commit.
- Never terminate a pre-existing user-owned app process. Track and close only the audit-owned PID.
- If Accessibility cannot safely activate the status item or Settings controls, stop automation and use a user-operated 60 fps recording paired with the trace. Do not fall back to coordinate guessing.
- Present the ranked hypotheses and captured evidence to the user before selecting a production container.

---

## Source Boundary and Current Evidence

The two selectors are not the same component:

| Boundary | Settings Agents | Menu-bar popover |
|---|---|---|
| Selector | `AgentSettingsTabStrip` | `MenuProviderTabStrip` |
| Layout | `ViewThatFits` with horizontal `ScrollView` fallback | fixed equal-width `HStack` |
| Selection owner | `SettingsView.selectedSettingsAgent` | `MenuBarPopoverView.selectedProvider` |
| Content replacement | `AgentsSettingsView` enum switch | `MenuBarPopoverView.providerContent` enum switch |
| Outer host | fixed Settings Page | intrinsic-height `MenuBarExtra(.window)` |
| Shared observation | `QuotaViewModel` | `QuotaViewModel` |

The existing Settings Destination compositor evidence is relevant but not dispositive:

- a 60 fps recording showed duplicated/displaced text across the Settings hierarchy;
- `.id(settings.selectedSettingsTab)` made the transition worse;
- a disabled-animation transaction did not fix it;
- both experiments were reverted;
- the nested Settings Agent selector has not yet been traced independently.

The menu surface adds a distinct hypothesis: switching between Codex and Claude can change intrinsic height, causing the private `MenuBarExtra(.window)` host to resize while the provider subtree is replaced.

---

## File Map

### Temporary diagnostic files

- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchTrace.swift` — argument-gated monotonic trace vocabulary.
- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchWindowProbe.swift` — observes the popover host window’s resize notifications.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderTabStrip.swift` — record menu button actions.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift` — record menu selection changes and host resize.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/CodexMenuContent.swift` — record Codex content appearance.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/ClaudeMenuContent.swift` — record Claude content appearance.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsTabStrip.swift` — record Settings button actions.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/SettingsView.swift` — record Settings Agent selection changes.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/CodexAgentSettingsView.swift` — record Codex Settings content appearance.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeAgentSettingsView.swift` — record Claude Settings content appearance.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — suppress provider startup for the diagnostic launch argument.

### Candidate production files

Only the evidence-selected candidate is modified:

- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentSettingsTabStrip.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/AgentsSettingsView.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuProviderTabStrip.swift`
- `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuBarPopoverView.swift`
- A new focused stable-host or AppKit adapter file if the selected prototype requires it.

### Evidence and documentation

- Create `docs/development/provider-switch-diagnostic-results.md` — trace table, frame references, tested hypotheses, and selected cause.
- Modify `docs/claude-usage-verification.md` — final signed-app matrix and exact unobserved states.
- Modify `docs/product/planning-board.md` — keep Verification until both loops pass.
- Modify `docs/superpowers/plans/2026-07-23-menu-bar-popover-review-followups.md` — link this executable plan.

---

### Task 1: Add argument-gated monotonic tracing

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchTrace.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchWindowProbe.swift`
- Modify the ten instrumentation call sites listed in the File Map.

**Interfaces:**
- Produces: `ProviderSwitchTrace.isEnabled`
- Produces: `ProviderSwitchTrace.record(surface:phase:provider:)`
- Produces: `ProviderSwitchWindowProbe(provider:)`
- Consumes: launch argument `--provider-switch-diagnostic`

- [x] **Step 1: Add the shared trace vocabulary.**

Create:

```swift
import Foundation
import OSLog

enum ProviderSwitchSurface: String {
    case settingsAgents
    case menuPopover
}

enum ProviderSwitchPhase: String {
    case buttonAction
    case selectionChanged
    case contentAppeared
    case windowResized
}

enum ProviderSwitchTrace {
    static let launchArgument = "--provider-switch-diagnostic"
    static let logger = Logger(
        subsystem: "CodexUsageMonitor",
        category: "ProviderSwitchDiagnostic"
    )

    static var isEnabled: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    @MainActor
    static func record(
        surface: ProviderSwitchSurface,
        phase: ProviderSwitchPhase,
        provider: AgentProvider,
        detail: String = ""
    ) {
        guard isEnabled else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        logger.notice(
            "[DEBUG-provider-switch] uptime=\(uptime, format: .fixed(precision: 6), privacy: .public) surface=\(surface.rawValue, privacy: .public) phase=\(phase.rawValue, privacy: .public) provider=\(provider.rawValue, privacy: .public) detail=\(detail, privacy: .public)"
        )
    }
}
```

- [x] **Step 2: Add a popover host resize probe.**

Create:

```swift
import AppKit
import SwiftUI

struct ProviderSwitchWindowProbe: NSViewRepresentable {
    let provider: AgentProvider

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(provider: provider)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.provider = provider
        nsView.observeCurrentWindow()
    }

    final class ProbeView: NSView {
        var provider: AgentProvider
        private weak var observedWindow: NSWindow?

        init(provider: AgentProvider) {
            self.provider = provider
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observeCurrentWindow()
        }

        func observeCurrentWindow() {
            guard ProviderSwitchTrace.isEnabled else { return }
            guard observedWindow !== window else { return }
            NotificationCenter.default.removeObserver(self)
            observedWindow = window
            guard let window else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }

        @objc private func windowDidResize(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            ProviderSwitchTrace.record(
                surface: .menuPopover,
                phase: .windowResized,
                provider: provider,
                detail: NSStringFromRect(window.frame)
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
```

- [x] **Step 3: Instrument both selector actions before writing the binding.**

Use this exact action shape in `AgentSettingsTabStrip`:

```swift
Button {
    ProviderSwitchTrace.record(
        surface: .settingsAgents,
        phase: .buttonAction,
        provider: entry.provider
    )
    selection = entry.provider
} label: {
```

Use this exact action shape in `MenuProviderTabStrip`:

```swift
Button {
    ProviderSwitchTrace.record(
        surface: .menuPopover,
        phase: .buttonAction,
        provider: provider
    )
    selection = provider
} label: {
    Text(provider.tabTitle)
}
```

- [x] **Step 4: Instrument the two selection owners.**

Add to `SettingsView`:

```swift
.onChange(of: selectedSettingsAgent) { _, provider in
    ProviderSwitchTrace.record(
        surface: .settingsAgents,
        phase: .selectionChanged,
        provider: provider
    )
}
```

Extend the existing `MenuBarPopoverView` selection callback:

```swift
.onChange(of: selectedProvider) { _, newValue in
    ProviderSwitchTrace.record(
        surface: .menuPopover,
        phase: .selectionChanged,
        provider: newValue
    )
    viewModel.settings.selectedMenuProvider =
        MenuPopoverProviderCatalog.resolvedSelection(newValue)
}
```

Add the resize probe to the popover root without affecting layout:

```swift
.background {
    ProviderSwitchWindowProbe(provider: activeProvider)
        .frame(width: 0, height: 0)
}
```

- [x] **Step 5: Instrument provider content appearance.**

Attach the matching trace to the outermost view in each Codex/Claude Settings and menu content body:

```swift
.onAppear {
    ProviderSwitchTrace.record(
        surface: .menuPopover,
        phase: .contentAppeared,
        provider: .codex
    )
}
```

Use `.menuPopover`/`.settingsAgents` and `.codex`/`.claudeCode` for the four exact call sites.

- [x] **Step 6: Keep the diagnostic launch passive.**

Extend `QuotaViewModel.shouldStartProviderMonitoring(arguments:)`:

```swift
&& !arguments.contains(ProviderSwitchTrace.launchArgument)
```

This prevents diagnostic startup from triggering provider reads or Keychain prompts. The tab switching bug must be diagnosed independently from live refresh work first.

- [x] **Step 7: Verify diagnostic source and commit it separately.**

Run:

```bash
cd CodexUsageMonitor
swift build --disable-sandbox
swift test --disable-sandbox
cd ..
git diff --check
rg -n "\\[DEBUG-provider-switch\\]" CodexUsageMonitor/Sources
```

Expected:

- source build succeeds;
- the full suite has zero failures;
- diff check is empty;
- every temporary log is returned by the final `rg`.

Commit:

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor
git commit -m "Add provider switch diagnostic tracing"
```

---

### Task 2: Establish two red-capable signed-app feedback loops

**Files:**
- Create: `docs/development/provider-switch-diagnostic-results.md`
- Modify: none in production.

**Interfaces:**
- Consumes: `[DEBUG-provider-switch]` unified log events.
- Produces: timestamp-aligned trace/frame tables for Settings and menu loops.

- [x] **Step 1: Build and launch an audit-owned signed app.**

Run:

```bash
cd CodexUsageMonitor
bash Scripts/build-app.sh
log stream \
  --style compact \
  --level info \
  --predicate 'subsystem == "CodexUsageMonitor" AND category == "ProviderSwitchDiagnostic"'
```

In a separate shell, launch:

```bash
open -n .build/CodexUsageMonitor.app --args --provider-switch-diagnostic
```

Before launch, record existing PIDs with:

```bash
pgrep -x CodexUsageMonitor
```

After launch, identify the one new PID. If the new PID cannot be distinguished safely, stop and do not close any process.

- [ ] **Step 2: Capture the Settings Agents loop.**

Open Settings through the normal app path. Record a 60 fps screen capture and run:

1. Context Rail hidden.
2. Codex → Claude → Codex, 20 transitions, one click per second.
3. Context Rail visible.
4. Repeat the same 20 transitions.
5. Repeat both runs using left/right keyboard commands.

For every transition, record:

```text
buttonAction uptime
selectionChanged uptime
contentAppeared uptime
first visually changed frame
first settled frame
duplicate/displaced frame: yes/no
ignored click: yes/no
```

The loop is red when any click lacks a matching selection change, selection-to-content latency exceeds 16.7 ms on an idle main thread, or a captured frame contains duplicated/displaced old and new content.

- [ ] **Step 3: Capture the menu loop.**

Open the production popover and record:

1. Codex → Claude → Codex, 20 transitions without closing.
2. Repeat with keyboard focus and activation.
3. Repeat with the naturally available cached/unavailable state.

For every transition, add `windowResized uptime/frame` to the trace table.

The loop is red when a click is ignored, the selection or content phase is delayed, old/new content coexist in a frame, or a nonintentional second resize occurs after the first settled frame.

- [ ] **Step 4: Minimize each red loop independently.**

Remove one factor per rerun:

- Context Rail visibility;
- pointer versus keyboard;
- `ViewThatFits` fitting versus overflow width;
- notification strip;
- cached/unavailable content;
- unequal versus equal provider content height;
- active refresh versus passive state.

Stop minimizing when removing any remaining factor makes the loop green. Record the minimal Settings scenario and minimal menu scenario separately.

- [ ] **Step 5: Stop if a red-capable loop cannot be established.**

If Accessibility blocks safe control, preserve:

- the audit-owned PID;
- the trace log;
- the exact requested 20-cycle script;
- the user’s 60 fps recording with timestamp alignment.

Do not continue to prototype selection containers until the exact user symptom is captured with a matching trace.

Progress on 2026-07-24: the Settings loop is red and minimized to the fitting
tab-strip branch with passive provider state. Pointer and keyboard delivery also
passed with the Context Rail visible. The menu action/selection/content/resize
loop is deterministic, but the automated display recording did not reliably
retain the transient `MenuBarExtra` panel, so menu frame alignment and the
remaining one-second/rail/keyboard recording matrix stay open. See
`docs/development/provider-switch-diagnostic-results.md`.

- [ ] **Step 6: Commit only the evidence document.**

The results document must contain:

```markdown
## Settings Agents result

| Transition | Action → selection | Selection → content | Settled frames | Verdict |
|---|---:|---:|---:|---|

## Menu popover result

| Transition | Action → selection | Selection → content | Window resize | Settled frames | Verdict |
|---|---:|---:|---:|---:|---|

## Minimal red scenarios

- Settings:
- Menu:
```

The committed document must contain the observed scenarios, not empty labels. If no scenario is red, state “No red-capable reproduction,” list every attempted loop, and stop the plan.

Commit:

```bash
git add docs/development/provider-switch-diagnostic-results.md
git commit -m "Record provider switch reproduction evidence"
```

---

### Task 3: Rank and test falsifiable hypotheses

**Files:**
- Modify: `docs/development/provider-switch-diagnostic-results.md`
- Temporary prototype changes only after the user evidence checkpoint.

**Interfaces:**
- Consumes: minimized red loops from Task 2.
- Produces: one confirmed cause per affected surface, or an explicit split diagnosis.

- [x] **Step 1: Rank hypotheses from the first divergent boundary.**

Use this evidence mapping:

1. **Hit testing/event delivery**
   - Prediction: missing `.buttonAction`; keyboard remains immediate.
2. **Main-actor blockage**
   - Prediction: `.buttonAction` exists but `.selectionChanged` or `.contentAppeared` is delayed on both surfaces.
3. **SwiftUI/AppKit subtree compositing**
   - Prediction: trace phases are immediate, but frames contain old and new subtrees.
4. **Menu intrinsic-height host resize**
   - Prediction: menu artifacts align with `windowResized`; Settings does not share that resize boundary.
5. **Settings `ViewThatFits` branch replacement**
   - Prediction: only Settings reproduces near the fit threshold; forcing the fitting branch or overflow branch removes it.

- [x] **Step 2: Show the ranked list and trace evidence to the user.**

Do not select a production fix before this checkpoint. Record any user evidence that changes the order.

**Checkpoint update — 2026-07-24:** The user accepted the menu's first
equal-height prototype after visually confirming that both the stuck switch and
duplicated/displaced content were gone. The signed trace held one `340 × 446`
host frame across 20 switches. The user then narrowed active implementation to
Settings Agents only; global Settings destination switching and larger menu tab
hit areas are documented as deferred.

- [ ] **Step 3: Test one variable at a time.**

For Settings, compare these temporary prototypes against the same red loop:

1. existing `ViewThatFits` baseline;
2. a viewport-filling minimum envelope around the provider content inside the
   existing shared `SettingsPage`;
3. stable host retaining both provider children;
4. native `TabView(selection:)` using `AgentProvider` values;
5. `NSTabViewController` adapter.

For the menu, compare:

1. existing enum switch baseline;
2. native `TabView(selection:)`;
3. stable host retaining both provider children;
4. AppKit child-controller host.

After each prototype:

```bash
bash CodexUsageMonitor/Scripts/build-app.sh
```

Run the exact minimized loop. Revert that prototype before applying the next so only one variable changes.

- [ ] **Step 4: Reject false fixes.**

A prototype is rejected if it:

- hides the artifact without removing trace/frame divergence;
- loses focus or VoiceOver selection semantics;
- resets Settings scroll position;
- changes Context Rail state;
- introduces menu scrolling;
- refreshes on selection;
- causes a new host-window resize;
- depends on `.id`, disabled animation, delay, or window recreation.

- [ ] **Step 5: Record the confirmed cause.**

The evidence document must name:

- first divergent trace boundary;
- confirmed hypothesis and falsified alternatives;
- winning prototype;
- whether Settings and menu share a cause;
- whether an automated regression seam exists.

Commit:

```bash
git add docs/development/provider-switch-diagnostic-results.md
git commit -m "Identify provider switch root cause"
```

---

### Task 4: Convert the winning prototype into the smallest production fix

**Files:**
- Modify only the evidence-selected files from the Candidate production files list.
- Test: create a focused XCTest only if Task 3 identifies a deterministic nonvisual seam.

**Interfaces:**
- Preserves: `Binding<AgentProvider>` selection.
- Preserves: Settings Agent session-only ownership.
- Preserves: menu provider persistence in `AppSettings.selectedMenuProvider`.
- Produces: stable provider transition with correct pointer, keyboard, focus, and accessibility behavior.

- [ ] **Step 1: Create the regression before the fix when a correct seam exists.**

If the root cause is deterministic layout/container state, write a test that exercises that state transition and fails before the fix. If the root cause is private-host compositing with no package-test seam, document the signed frame loop as the regression boundary and add no false-confidence unit test.

- [ ] **Step 2: Apply only the confirmed production change.**

Keep the public bindings and provider catalogs unchanged. Do not bundle tab styling, view-model splitting, or unrelated navigation refactors.

- [ ] **Step 3: Re-run both original loops.**

Required pass:

- 20/20 pointer transitions and 20/20 keyboard transitions on Settings with both rail states;
- 20/20 pointer and keyboard transitions in the popover;
- every action has exactly one selection change;
- no temporarily stuck selection;
- no duplicated/displaced frame;
- no post-settle movement except a single intentional menu height change;
- focus and VoiceOver remain usable.

- [ ] **Step 4: Run source verification.**

```bash
cd CodexUsageMonitor
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
```

- [ ] **Step 5: Commit the root-cause fix.**

Use a cause-naming commit message, for example:

```bash
git commit -m "Stabilize provider content host during selection"
```

Do not use that example unless the stable-host hypothesis is actually confirmed.

---

### Task 5: Remove diagnostics and complete signed acceptance

**Files:**
- Delete: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchTrace.swift`
- Delete: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/ProviderSwitchWindowProbe.swift`
- Remove all temporary call sites.
- Modify the evidence and verification documents in the File Map.

**Interfaces:**
- Produces: production source containing no diagnostic launch argument or tagged logs.

- [ ] **Step 1: Remove all temporary diagnostics.**

Run:

```bash
rg -n "\\[DEBUG-provider-switch\\]|provider-switch-diagnostic|ProviderSwitchTrace|ProviderSwitchWindowProbe" CodexUsageMonitor/Sources
```

Expected after cleanup: no matches.

- [ ] **Step 2: Rebuild the signed app from cleaned source.**

```bash
bash CodexUsageMonitor/Scripts/build-app.sh
```

- [ ] **Step 3: Re-run the full acceptance matrix.**

Repeat both 20-cycle loops in:

- Light and Dark;
- Context Rail hidden and visible;
- pointer and keyboard;
- naturally available confirmed, cached, refreshing, and unavailable states;
- VoiceOver entry, selection announcement, activation, and escape.

- [ ] **Step 4: Update status truthfully.**

Move the planning-board item out of Verification only if both surfaces pass the matrix. If either remains red, keep Verification and record the exact remaining surface/state.

- [ ] **Step 5: Run final verification and commit cleanup/evidence.**

```bash
cd CodexUsageMonitor
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
git status --short
```

Commit:

```bash
git add CodexUsageMonitor/Sources docs
git commit -m "Complete provider switch diagnostic acceptance"
```

Do not push until the user explicitly approves the resulting commits.

---

## Completion Criteria

- Both exact user-reported symptoms have red-capable baseline evidence.
- The first divergent boundary is identified separately for Settings and menu.
- A production approach is selected only after the user sees the ranked evidence.
- Every pointer and keyboard selection produces exactly one immediate state change.
- No selection becomes temporarily stuck.
- No old/new provider content is duplicated or displaced in captured frames.
- Settings preserves destination, Context Rail, scroll, focus, and appearance state.
- The menu remains passive, non-scrolling, and stable in height after its intentional transition.
- VoiceOver and keyboard behavior pass in Light and Dark.
- All temporary diagnostic code and logs are removed.
- Full source and signed-app verification are recorded without inferred coverage.
