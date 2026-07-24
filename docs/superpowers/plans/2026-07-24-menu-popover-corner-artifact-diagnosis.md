# Menu Popover Corner Artifact Diagnosis and Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce and remove the remaining square fill, halo, doubled border, detached shadow, or first-frame flash visible around the rounded menu-bar popover corners.

**Architecture:** Instrument the real signed `MenuBarExtra(.window)` host at lifecycle and resize boundaries, then align monotonic logs with native-pixel first-frame captures. Compare one rendering owner at a time: current asynchronous transparent-window configuration, synchronous host configuration, content-view masking, SwiftUI stroke/shadow ownership, and an AppKit popover fallback. Implement only the smallest prototype whose evidence removes the exact artifact in every required state.

**Tech Stack:** Swift 6.2, SwiftUI for macOS 14+, AppKit `NSWindow`/`CALayer`, `OSLog`, Swift Package Manager, signed-app frame capture.

**Status — 2026-07-24:** This is now the **last open visual-defect track** on the branch. The provider-switch instability is resolved and visually confirmed (stable intrinsic host geometry: shared 288-point menu content floor plus the Settings viewport-filling envelope), and the too-small provider-tab hit area is corrected under a separate bounded plan ([provider-tab hit area](2026-07-24-provider-tab-hit-area.md)). Neither of those changes touches window/layer rendering ownership, so this plan is unaffected and remains the plan of record. The corner artifact is still **not fixed**; no fix is claimed. This plan is unexecuted (all task steps below are open) and is ready to run when signed-app first-frame capture is authorized.

## Global Constraints

- Work on `feature/multiprovider-menubar-popover`; do not push without explicit approval.
- The current `MenuPopoverWindowConfigurator` change is not accepted as a fix; user observation overrides its earlier commit message.
- Do not assume `NSWindow.backgroundColor = .clear` changes private `MenuBarExtra(.window)` frame, material, border, or shadow layers.
- Diagnose first-frame timing before changing production rendering ownership.
- Change one rendering variable per prototype and rebuild the signed app after each.
- Keep the shell 340 points wide and preserve the 14-point intended corner radius unless the evidence-selected fallback intentionally squares the shell.
- Preserve semantic Light/Dark colors, provider tabs, fixed header/footer, no scrolling, passive open, Escape dismissal, and in-place refresh.
- Do not recreate the window, add delayed writes, or hide the defect with an oversized background.
- Tag all temporary logs `[DEBUG-popover-corners]` and remove them before production commit.
- Never attach LLDB just to open/focus the popover.
- Never terminate a pre-existing user-owned app process.
- If safe automated status-item control is unavailable, stop automation and request user-operated first-frame recording. Do not use guessed coordinates.
- Show the ranked evidence to the user before choosing between rounded-host repair and the square-shell fallback.

---

## Current Source State

`MenuPopoverChrome` currently:

1. fixes content width at 340 points;
2. paints `theme.windowBackground`;
3. clips to a 14-point rounded rectangle;
4. adds two rounded `stroke` overlays;
5. embeds `MenuPopoverWindowConfigurator`.

`MenuPopoverWindowConfigurator` currently:

1. creates a zero-purpose `NSView`;
2. schedules configuration with `DispatchQueue.main.async` from both `makeNSView` and `updateNSView`;
3. sets `window.isOpaque = false`;
4. sets `window.backgroundColor = .clear`;
5. leaves `window.hasShadow = true`.

Unmeasured boundaries:

- whether the first visible frame precedes the asynchronous configuration;
- the private host window class and frame/content layout;
- content-view layer radius and mask;
- whether the host has a visual-effect/material subview;
- whether the server shadow follows alpha or rectangular host bounds;
- whether provider height changes invalidate backing/shadow geometry;
- whether the two centered SwiftUI strokes create a corner halo independent of the host.

---

## File Map

### Temporary diagnostics

- Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/MenuPopoverCornerTrace.swift` — argument-gated structured window/layer logging.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverWindowConfigurator.swift` — lifecycle tracing without changing rendering behavior.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverChrome.swift` — optional render-phase marker only.
- Modify `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift` — suppress provider startup for `--popover-corner-diagnostic`.

### Prototype candidates

- Modify `MenuPopoverWindowConfigurator.swift` for synchronous `viewDidMoveToWindow` configuration.
- Modify `MenuPopoverChrome.swift` for `strokeBorder`/SwiftUI-shadow ownership.
- Create `MenuPopoverContentMaskConfigurator.swift` only for the content-layer-mask prototype.
- Create `AppKitMenuPopoverPresenter.swift` only if the private `MenuBarExtra(.window)` host proves uncontrollable.

### Evidence and documentation

- Create `docs/development/menu-popover-corner-diagnostic-results.md`.
- Modify `docs/design/menu-bar-popover/SPEC.md`.
- Modify `docs/claude-usage-verification.md`.
- Modify `docs/product/planning-board.md`.
- Modify `docs/superpowers/plans/2026-07-23-menu-bar-popover-review-followups.md`.

---

### Task 1: Instrument the real host without changing rendering

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/MenuPopoverCornerTrace.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/MenuPopoverWindowConfigurator.swift`
- Modify: `CodexUsageMonitor/Sources/CodexUsageMonitor/Menu/QuotaViewModel.swift`

**Interfaces:**
- Produces: `MenuPopoverCornerTrace.launchArgument`
- Produces: `MenuPopoverCornerTrace.describe(window:phase:)`
- Consumes: `--popover-corner-diagnostic`

- [ ] **Step 1: Add structured host/layer tracing.**

Create:

```swift
import AppKit
import OSLog

enum MenuPopoverCornerTrace {
    static let launchArgument = "--popover-corner-diagnostic"
    static let logger = Logger(
        subsystem: "CodexUsageMonitor",
        category: "PopoverCornerDiagnostic"
    )

    static var isEnabled: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    @MainActor
    static func describe(window: NSWindow?, phase: String) {
        guard isEnabled, let window else { return }
        let contentView = window.contentView
        let layer = contentView?.layer
        let uptime = ProcessInfo.processInfo.systemUptime
        logger.notice(
            "[DEBUG-popover-corners] uptime=\(uptime, format: .fixed(precision: 6), privacy: .public) phase=\(phase, privacy: .public) class=\(String(describing: type(of: window)), privacy: .public) frame=\(NSStringFromRect(window.frame), privacy: .public) contentFrame=\(NSStringFromRect(contentView?.frame ?? .zero), privacy: .public) opaque=\(window.isOpaque, privacy: .public) backgroundAlpha=\(window.backgroundColor.alphaComponent, privacy: .public) hasShadow=\(window.hasShadow, privacy: .public) contentWantsLayer=\(contentView?.wantsLayer ?? false, privacy: .public) cornerRadius=\(layer?.cornerRadius ?? 0, privacy: .public) masksToBounds=\(layer?.masksToBounds ?? false, privacy: .public) subviews=\(contentView?.subviews.count ?? 0, privacy: .public)"
        )
    }
}
```

- [ ] **Step 2: Replace the zero-purpose `NSView` with a lifecycle-observing view, preserving current async behavior.**

Use:

```swift
struct MenuPopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ProbeView {
        ProbeView()
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        MenuPopoverCornerTrace.describe(
            window: nsView.window,
            phase: "updateNSView-before-async"
        )
        DispatchQueue.main.async {
            Self.configure(nsView.window, phase: "updateNSView-async")
        }
    }

    final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            MenuPopoverCornerTrace.describe(
                window: window,
                phase: "viewDidMoveToWindow-before-async"
            )
            installObservers()
            DispatchQueue.main.async {
                MenuPopoverWindowConfigurator.configure(
                    self.window,
                    phase: "viewDidMoveToWindow-async"
                )
            }
        }

        private func installObservers() {
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            MenuPopoverCornerTrace.describe(
                window: notification.object as? NSWindow,
                phase: "didBecomeKey"
            )
        }

        @objc private func windowDidResize(_ notification: Notification) {
            MenuPopoverCornerTrace.describe(
                window: notification.object as? NSWindow,
                phase: "didResize"
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }

    @MainActor
    private static func configure(_ window: NSWindow?, phase: String) {
        MenuPopoverCornerTrace.describe(window: window, phase: "\(phase)-before")
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        MenuPopoverCornerTrace.describe(window: window, phase: "\(phase)-after")
    }
}
```

This task deliberately preserves the asynchronous mutation so the current behavior can be measured before testing a synchronous alternative.

- [ ] **Step 3: Keep the diagnostic launch passive.**

Extend `QuotaViewModel.shouldStartProviderMonitoring(arguments:)`:

```swift
&& !arguments.contains(MenuPopoverCornerTrace.launchArgument)
```

- [ ] **Step 4: Verify and commit diagnostics separately.**

```bash
cd CodexUsageMonitor
swift build --disable-sandbox
swift test --disable-sandbox
cd ..
git diff --check
rg -n "\\[DEBUG-popover-corners\\]" CodexUsageMonitor/Sources
```

Commit:

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor
git commit -m "Instrument menu popover corner rendering"
```

---

### Task 2: Establish the red-capable first-frame loop

**Files:**
- Create: `docs/development/menu-popover-corner-diagnostic-results.md`

**Interfaces:**
- Consumes: `[DEBUG-popover-corners]` events and native-resolution frame captures.
- Produces: an exact artifact classification and first divergent render phase.

- [ ] **Step 1: Build and launch one audit-owned signed instance.**

```bash
cd CodexUsageMonitor
bash Scripts/build-app.sh
log stream \
  --style compact \
  --level info \
  --predicate 'subsystem == "CodexUsageMonitor" AND category == "PopoverCornerDiagnostic"'
```

Launch separately:

```bash
open -n .build/CodexUsageMonitor.app --args --popover-corner-diagnostic
```

Record pre-launch and post-launch PIDs. Close only the new PID after capture.

- [ ] **Step 2: Capture the current failure at native resolution.**

Record at 60 fps or higher:

1. first open, including at least 500 ms before appearance and one second after;
2. five close/reopen cycles;
3. Codex → Claude → Codex;
4. left and right screen edges;
5. Light and Dark appearance.

Extract lossless frames around:

- first nonempty popover pixel;
- `viewDidMoveToWindow-before-async`;
- `viewDidMoveToWindow-async-after`;
- `didBecomeKey`;
- every `didResize`;
- first visually settled frame.

- [ ] **Step 3: Classify each corner independently.**

For top-left, top-right, bottom-left, and bottom-right, record:

```text
square fill
light/dark halo
doubled border
detached/rectangular shadow
one-frame flash
provider-switch-only artifact
clean
```

The loop is red if any corner has any category other than `clean` in any captured frame.

- [ ] **Step 4: Minimize the failure.**

Change only one state per capture:

- host shadow on/off;
- shell border/outline present/absent;
- Codex versus Claude height;
- first open versus reopened;
- Light versus Dark;
- before versus after async configuration.

Do not commit these probes. Restore the diagnostic baseline after each.

- [ ] **Step 5: Record the baseline evidence.**

Create:

```markdown
## Artifact classification

| State | TL | TR | BL | BR | First bad frame | First clean frame |
|---|---|---|---|---|---:|---:|

## Host timeline

| Phase | Opaque | Background alpha | Shadow | Layer radius | Mask | Frame |
|---|---:|---:|---:|---:|---:|---|

## Minimal red scenario

State the smallest capture sequence that still contains the user-reported artifact.
```

Commit:

```bash
git add docs/development/menu-popover-corner-diagnostic-results.md
git commit -m "Record popover corner reproduction evidence"
```

If the loop cannot reproduce the reported artifact, stop and request the user’s original screenshot/video at native resolution. Do not proceed to fixes from source inspection alone.

---

### Task 3: Rank and test one rendering-owner hypothesis at a time

**Files:**
- Modify: `docs/development/menu-popover-corner-diagnostic-results.md`
- Temporary changes to the prototype candidate files.

**Interfaces:**
- Consumes: minimized red capture loop.
- Produces: one confirmed rendering owner and one accepted prototype.

- [ ] **Step 1: Rank these hypotheses from the captured timeline.**

1. **Delayed host configuration**
   - Prediction: bad frames occur before an `*-async-after` phase and disappear afterward.
2. **Private host material/frame remains visible**
   - Prediction: artifact persists after clear/nonopaque state; host/content subviews or layer geometry do not match the shell.
3. **Rectangular server shadow**
   - Prediction: fill corners are transparent but the halo/shadow stays square; `hasShadow = false` removes only the artifact.
4. **SwiftUI double stroke or antialiasing**
   - Prediction: artifact follows the shell border/outline even with host shadow disabled; replacing centered strokes with `strokeBorder` removes it.
5. **Resize invalidation**
   - Prediction: artifact aligns with `didResize` and appears most strongly on provider switches.

- [ ] **Step 2: Show the ranked evidence to the user.**

Include native-pixel crops and the host timeline. Obtain direction before accepting a visually different square-shell fallback or replacing `MenuBarExtra`.

- [ ] **Step 3: Prototype synchronous configuration.**

Test only if hypothesis 1 is viable. In `viewDidMoveToWindow`, call:

```swift
MenuPopoverWindowConfigurator.configure(
    window,
    phase: "viewDidMoveToWindow-synchronous"
)
```

Remove the corresponding async dispatch for this prototype. Rebuild the signed app and run the minimal red loop.

- [ ] **Step 4: Prototype server-shadow removal plus SwiftUI-owned shadow.**

Test only if hypothesis 3 is viable:

```swift
window.hasShadow = false
```

Restore one shell shadow:

```swift
.shadow(
    color: theme.shellShadow,
    radius: MenuPopoverTheme.shellShadowRadius,
    y: MenuPopoverTheme.shellShadowY
)
```

Rebuild and capture. Reject it if the shadow clips at window bounds or creates a second halo.

- [ ] **Step 5: Prototype inset strokes.**

Test only if hypothesis 4 is viable. Replace both centered `stroke` overlays with:

```swift
RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
    .strokeBorder(
        theme.border,
        lineWidth: MenuPopoverTheme.shellBorderWidth
    )
```

and:

```swift
RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
    .inset(by: MenuPopoverTheme.shellBorderWidth)
    .strokeBorder(
        theme.shellOutline,
        lineWidth: MenuPopoverTheme.shellOutlineWidth
    )
```

Rebuild and capture all four corners.

- [ ] **Step 6: Prototype content-view layer ownership.**

Test only if hypothesis 2 is viable. Create an AppKit configurator that applies:

```swift
contentView.wantsLayer = true
contentView.layer?.cornerRadius = MenuPopoverTheme.shellCornerRadius
contentView.layer?.cornerCurve = .continuous
contentView.layer?.masksToBounds = true
```

Do not combine this with a shadow change on the first run. Capture whether masking removes fill but clips the shadow or controls.

- [ ] **Step 7: Prototype the explicit fallback architectures.**

Only if the private host cannot render one clean rounded owner:

1. square `MenuPopoverChrome` matching the host;
2. AppKit-owned `NSPopover`/status-item presenter with one explicit content controller.

The square option is a product/design fallback. The AppKit option is an architecture change and must also prove status-item toggling, dismissal, focus, Escape, Settings opening, and process lifecycle.

- [ ] **Step 8: Select by evidence, not preference.**

The accepted prototype must:

- remove every artifact category from every captured frame;
- avoid a first-frame flash;
- survive five reopen cycles and both provider heights;
- preserve the intended border and shadow in Light/Dark;
- preserve keyboard, VoiceOver, Escape, and footer actions;
- avoid window recreation or delayed writes.

Record the confirmed hypothesis, rejected prototypes, and accepted owner in the evidence document.

Commit only the evidence update:

```bash
git add docs/development/menu-popover-corner-diagnostic-results.md
git commit -m "Identify popover corner rendering owner"
```

---

### Task 4: Implement the evidence-selected corner fix

**Files:**
- Modify only the accepted candidate files from the File Map.
- Test: no automated visual test unless Task 3 discovers a deterministic layer-configuration seam.

**Interfaces:**
- Preserves: `MenuPopoverChrome<Content>`.
- Preserves: 340-point width and provider content.
- Produces: one rendering owner for fill, clip, border, and shadow.

- [ ] **Step 1: Add a regression only at a correct seam.**

If the cause is lifecycle ordering or layer configuration that can be asserted without the private signed host, add a focused test/harness that fails before the fix. If only frame capture reaches the real bug, document the signed native-pixel loop as the regression boundary and do not add a shallow test.

- [ ] **Step 2: Apply the one confirmed production change.**

Do not combine synchronous configuration, layer masking, stroke changes, and shadow ownership unless Task 3 proved that each is load-bearing.

- [ ] **Step 3: Re-run the original unminimized capture matrix.**

Pass requires:

- no square fill;
- no halo;
- no doubled border;
- no detached/rectangular shadow;
- no first-frame flash;
- no provider-switch resize artifact;
- all four corners clean in Light and Dark.

- [ ] **Step 4: Run interaction acceptance.**

Verify:

- status-item open/close cycles;
- outside-click dismissal;
- Escape dismissal;
- provider switching;
- Refresh Now staying open;
- Notification Settings, Preferences, and Quit;
- keyboard focus and VoiceOver.

- [ ] **Step 5: Run source verification and commit the cause-specific fix.**

```bash
cd CodexUsageMonitor
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
```

Use a cause-specific commit message. Examples:

```bash
git commit -m "Configure popover host before first frame"
git commit -m "Move popover shadow ownership into SwiftUI"
git commit -m "Mask the popover content host to its shell"
```

Use only the message matching the confirmed cause.

---

### Task 5: Remove diagnostics and reconcile documentation

**Files:**
- Delete: `CodexUsageMonitor/Sources/CodexUsageMonitor/Diagnostics/MenuPopoverCornerTrace.swift`
- Remove temporary lifecycle trace code and launch suppression.
- Modify all evidence/documentation files in the File Map.

**Interfaces:**
- Produces: clean production source and truthful signed-app evidence.

- [ ] **Step 1: Remove every diagnostic marker.**

```bash
rg -n "\\[DEBUG-popover-corners\\]|popover-corner-diagnostic|MenuPopoverCornerTrace" CodexUsageMonitor/Sources
```

Expected after cleanup: no matches.

- [ ] **Step 2: Rebuild the signed app from cleaned source and repeat acceptance.**

```bash
bash CodexUsageMonitor/Scripts/build-app.sh
```

Repeat the full Task 4 frame and interaction matrix. A diagnostic build is not final evidence.

- [ ] **Step 3: Update the written contract.**

Record:

- the actual root cause;
- the single owner of fill/clip/border/shadow;
- screenshots or frame references;
- every tested appearance/state;
- any state not manufactured.

Remove language claiming the old transparent-window change fixed the artifact.

- [ ] **Step 4: Run final verification.**

```bash
cd CodexUsageMonitor
swift test --disable-sandbox
swift build --disable-sandbox
cd ..
git diff --check
git status --short
```

- [ ] **Step 5: Commit cleanup and evidence.**

```bash
git add CodexUsageMonitor/Sources docs
git commit -m "Complete popover corner acceptance"
```

Do not push without explicit user approval.

---

## Completion Criteria

- The user-reported artifact is reproduced in the actual signed popover.
- First-frame and settled-frame host state are aligned with native-pixel captures.
- The root cause is proven by a one-variable prototype.
- Fill, clipping, border, and shadow have one explicit owner.
- Every corner is clean on first open, five reopen cycles, both provider heights, screen edges, Light, and Dark.
- Provider switching does not reintroduce a resize corner artifact.
- Keyboard, VoiceOver, Escape, outside-click dismissal, refresh, Settings, and Quit still work.
- All temporary diagnostic code is removed.
- Source tests/build and signed-app evidence are recorded.
- Nothing is pushed until separately approved.
