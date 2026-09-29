# Content-Fitted Menu Panel — Code Structure (Draft)

Companion to [the implementation plan](2026-09-29-content-fitted-menu-panel.md). Files marked "from" or "replaces" a trial type start from the archived trial code on `archive/rejected-menu-trials-2026-09-28` (see the plan's Starting material). **Draft, not compiled.** Signatures and key bodies only. They settle ownership and ordering before implementation. Names are proposals; the implementing agent should match the surrounding code where it differs.

## Decisions this structure encodes (user, 2026-09-29)

| Topic | Decision |
|---|---|
| Root view | One `MenuSurface` fed by snapshots, for both live and fixture data |
| Grow target on tab click | Pre-measure the target snapshot offscreen, then grow to `max(current, target)` |
| Refresh-driven changes | The controller gates snapshots: rebuild → measure → grow → publish, the same pipeline as tab clicks |
| Pre-measure too small | Correct at settle (grow late) and log an `os_log` fault in debug builds with both heights |
| Activation | `.nonactivatingPanel`; the frontmost app keeps focus; Settings commands activate the app |
| Open/close | About a 0.1 s alpha fade. Opacity only, never geometry |
| Outside click | Close and let the click pass through (global monitor only observes) |
| Keyboard | Focus + Return only (no new shortcuts). Every path goes through the same selection intent |
| Settings | Main-menu ⌘, dispatch to the SwiftUI Settings scene's installed command |
| After promotion | Keep: `MenuBarExtra` kill switch, fixture demo. Delete: popover trial, window-popover gate |
| First PR | Prototype behind `--menu-presentation=panel`; production unchanged. Promotion in a second PR |
| Before either PR | Commit the pending Claude work as its own reviewed commits |

## Ownership and data flow

```
QuotaViewModel ─ objectWillChange ─┐                     (model never reaches SwiftUI directly)
AppSettings    ─ objectWillChange ─┤
Enrollment     ─ objectWillChange ─┤
                                   ▼
MenuPanelController ──owns──► MenuContentPipeline ──reads──► MenuSnapshotSource (Live | Fixture)
   │  NSStatusItem, MenuPanel,       │  MenuSurfaceMeasurer (offscreen NSHostingView)
   │  monitors, fade, frame writes   │  MenuWindowEnvelope (pure policy)
   │                                 ▼
   │                           MenuPanelModel (@Published state)  ──►  MenuPanelRoot → MenuSurface
   │                                 ▲                                         │
   └──── applyHeight(h) ◄────────────┴── surfaceDidSettle(h) ◄── onGeometryChange
```

Rules:
- `MenuPanelController` is the only type that writes the window frame.
- `MenuSurface` observes only `MenuPanelModel`, never `QuotaViewModel`. Otherwise refreshed content would reach the screen before it was measured, and gating would be defeated.
- A window grow is always written *before* `model.publish(_:)`, in the same main-thread turn. A shrink is written only after the surface settles, one run-loop turn later, and is cancelled by any newer grow.

## File map

| File | Status | Role |
|---|---|---|
| `Menu/Panel/MenuPanelController.swift` | new (replaces `MenuPresentationController`) | Status item, panel, present/dismiss, fade, monitors, frame writes |
| `Menu/Panel/MenuPanel.swift` | new (replaces `MenuTrialPanel`) | `NSPanel` subclass: non-activating, key-capable, Esc |
| `Menu/Panel/MenuContentPipeline.swift` | new | Selection/refresh → measure → envelope → publish |
| `Menu/Panel/MenuWindowEnvelope.swift` | new | Pure grow/shrink policy with a generation guard (unit-tested) |
| `Menu/Panel/MenuSurfaceMeasurer.swift` | new | Offscreen, single-pass height measurement |
| `Menu/Panel/MenuPanelModel.swift` | new | `@Published` gated state for the root view |
| `Menu/Panel/MenuSnapshotSource.swift` | new | `LiveMenuSnapshotSource`, `FixtureMenuSnapshotSource` |
| `Menu/MenuSurface.swift` | new (from `MenuTrialSurface`) | The single renderer: tabs, header, viewport, footer |
| `Menu/MenuPanelState.swift` | new | Snapshot + selection + footer flags + diagnostic label |
| `Menu/MenuSurfaceActions.swift` | new | Command closures; `.inert` for measuring and fixtures |
| `Menu/MenuCommandRouter.swift` | new | Settings (⌘, dispatch), notifications destination, quit |
| `Menu/MenuHost.swift` | new (replaces `MenuPresentationMode`) | Host selection, fixture flag, kill switch |
| `Menu/MenuAdaptiveLayout.swift` | modify | Becomes the single-pass `MenuViewportLayout` (a `Layout`) |
| `Menu/MenuTrialView.swift`, `MenuTrialShell.swift`, `MenuPresentationSizing.swift`, `MenuTrialPanel.swift` | delete | Replaced by the files above |
| `MenuPresentationMode.popover` path | delete (PR 1) | Rejected trial |
| `WindowPopoverGateView.swift`, `MenuPopoverViabilityGate.swift` | delete (promotion PR) | Obsolete viability check |
| `MenuBarPopoverView`, `MenuPopoverChrome`, `MenuPopoverWindowConfigurator` | unchanged in PR 1; kept as the kill switch after promotion | Legacy `MenuBarExtra` host |

## Code elements

### `MenuHost` — host selection and kill switch

```swift
enum MenuHost: Equatable {
    case menuBarExtra   // accepted 2026-09-28 host (stable 860 pt transparent window)
    case panel          // content-fitted owned panel

    /// PR 1: panel only on request. Promotion PR: panel by default,
    /// `--menu-host=legacy` or the `MenuHostLegacy` default restores MenuBarExtra.
    static var current: MenuHost {
        let arguments = CommandLine.arguments
        if arguments.contains("--menu-presentation=panel") { return .panel }
        return .menuBarExtra
        // Promotion PR replaces the line above with:
        // if arguments.contains("--menu-host=legacy")
        //     || UserDefaults.standard.bool(forKey: "MenuHostLegacy") { return .menuBarExtra }
        // return .panel
    }

    static var usesFixtures: Bool { /* unchanged: --menu-fixture or Info.plist key */ }
}
```

`CodexUsageMonitorApp` changes from `MenuPresentationMode.current == nil` to `MenuHost.current == .menuBarExtra` on the production `MenuBarExtra`. `ApplicationDelegate` creates `MenuPanelController` when `MenuHost.current == .panel`.

### `MenuPanelState` and `MenuSurfaceActions` — what the surface renders

```swift
/// Everything MenuSurface needs, as values. Equality lets the pipeline skip
/// republishing an unchanged state after a burst of objectWillChange events.
struct MenuPanelState: Equatable {
    var selection: AgentProvider
    var snapshot: MenuContentSnapshot        // make Equatable (all members are value types)
    var keyboardShortcutsEnabled: Bool
    var diagnosticLabel: String?             // fixture only
}

struct MenuSurfaceActions {
    var select: (AgentProvider) -> Void      // intent, never a direct state write
    var refresh: () -> Void
    var connect: () -> Void
    var signInWithBrowser: () -> Void
    var signInWithCLI: () -> Void
    var openSystemNotificationSettings: () -> Void
    var openNotificationSettings: () -> Void
    var openPreferences: () -> Void
    var nextFixture: () -> Void
    var quit: () -> Void
    var dismiss: () -> Void

    /// Used by the measurer: identical layout, no side effects.
    static let inert = MenuSurfaceActions(select: { _ in }, refresh: {}, /* … all no-ops */)
}
```

### `MenuSurface` — the single renderer

This is `MenuTrialSurface` moved and changed in four ways: it takes a state and actions, the tab binding routes writes to the intent, the layout is single-pass, and it reports its settled height.

```swift
struct MenuSurface: View {
    let state: MenuPanelState
    let maximumHeight: CGFloat
    let actions: MenuSurfaceActions
    var onSettledHeight: (CGFloat) -> Void = { _ in }

    var body: some View {
        MenuViewportLayout(maximumHeight: maximumHeight) {
            header        // diagnostic row (fixture), MenuProviderTabStrip, MenuProviderHeader
            viewport      // ScrollViewReader { ScrollView { providerContent } }, reset on provider change
            footer        // MenuActionFooterRows
        }
        .frame(width: MenuPopoverTheme.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onSettledHeight($0) }
        .onExitCommand(perform: actions.dismiss)
    }

    /// The strip keeps its existing Binding API. Reads come from published
    /// state; writes become a selection intent, so pointer and keyboard
    /// (focus + Return) both go through the pipeline.
    private var selection: Binding<AgentProvider> {
        Binding(get: { state.selection }, set: { actions.select($0) })
    }

    // header / viewport / footer / providerContent: moved unchanged from MenuTrialSurface.
}
```

`onGeometryChange` is back-deployed to macOS 13 in current SDKs; confirm when compiling. If it isn't, use the existing `GeometryReader` + preference pattern.

### `MenuViewportLayout` — deterministic single-pass measurement

This replaces `MenuAdaptiveLayout`'s preference→`@State` round trip. That round trip is correct inside a live host (probe case 5), but it is not a pure function of its inputs, and the offscreen measurer needs a pure function. It is the same algorithm as the probe's `ViewportLayout`, which passed the overflow and switch cases in one layout pass. `MenuViewportOverflowTests` stays as its guard.

```swift
struct MenuViewportLayout: Layout {
    var maximumHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? MenuPopoverTheme.popoverWidth
        return CGSize(width: width, height: allocation(subviews, width: width).reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (subview, height) in zip(subviews, allocation(subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height
        }
    }

    /// [header, viewport, footer]. The viewport's ideal height is its content's
    /// height (ScrollView reports content as ideal on the scroll axis); it is
    /// proposed the smaller of that and the space left under the cap.
    private func allocation(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        precondition(subviews.count == 3, "header, viewport, footer")
        let unbounded = ProposedViewSize(width: width, height: nil)
        let header = subviews[0].sizeThatFits(unbounded).height
        let footer = subviews[2].sizeThatFits(unbounded).height
        let content = subviews[1].sizeThatFits(unbounded).height
        return [header, min(content, max(0, maximumHeight - header - footer)), footer]
    }
}
```

### `MenuWindowEnvelope` — the invariant, as a pure value

```swift
/// Window height is never smaller than committed content height, except for a
/// logged late grow when a pre-measurement was wrong. A shrink applies only if
/// no grow happened after it was proposed.
struct MenuWindowEnvelope: Equatable {
    var cap: CGFloat
    private(set) var windowHeight: CGFloat
    private(set) var committedContentHeight: CGFloat
    private(set) var generation = 0
    static let tolerance: CGFloat = 0.5

    /// Explicit: `private(set)` members would make the memberwise init private.
    init(cap: CGFloat) {
        self.cap = cap
        windowHeight = 0
        committedContentHeight = 0
    }

    enum Settlement: Equatable {
        case unchanged
        case shrink(to: CGFloat, generation: Int)       // apply next run-loop turn
        case lateGrow(to: CGFloat, premeasured: CGFloat) // apply now + log fault
    }

    /// Call before publishing. Returns a height to apply *before* the commit.
    mutating func prepare(committing premeasured: CGFloat) -> CGFloat? {
        generation += 1
        committedContentHeight = min(premeasured, cap)
        guard committedContentHeight > windowHeight + Self.tolerance else { return nil }
        windowHeight = committedContentHeight
        return windowHeight
    }

    /// Call with the live surface height after SwiftUI settles.
    mutating func settle(measured: CGFloat) -> Settlement {
        let height = min(measured, cap)
        if height > windowHeight + Self.tolerance {
            let premeasured = committedContentHeight
            windowHeight = height
            committedContentHeight = height
            return .lateGrow(to: height, premeasured: premeasured)
        }
        committedContentHeight = height
        guard height < windowHeight - Self.tolerance else { return .unchanged }
        return .shrink(to: height, generation: generation)
    }

    /// False if a newer `prepare` happened; the stale shrink is then dropped.
    mutating func applyShrink(to height: CGFloat, generation proposed: Int) -> Bool {
        guard proposed == generation, height >= committedContentHeight - Self.tolerance else { return false }
        windowHeight = height
        return true
    }
}
```

### `MenuSurfaceMeasurer` — offscreen pre-measurement

```swift
@MainActor
final class MenuSurfaceMeasurer {
    private let host = NSHostingView(rootView: MenuSurface(state: .placeholder, maximumHeight: 0, actions: .inert))

    init() { host.sizingOptions = [] }

    /// Same view, same width, same layout, inert actions, and the panel's
    /// appearance so font and material metrics match. Single pass by
    /// construction (MenuViewportLayout).
    func height(of state: MenuPanelState, maximumHeight: CGFloat, appearance: NSAppearance) -> CGFloat {
        host.appearance = appearance
        host.rootView = MenuSurface(state: state, maximumHeight: maximumHeight, actions: .inert)
        host.frame.size.width = MenuPopoverTheme.popoverWidth
        host.layoutSubtreeIfNeeded()
        return ceil(host.fittingSize.height)
    }
}
```

Known source of mismatch: the offscreen host has no hover or scroll state. The chart hover row already has a fixed height (`activityHoverDetailHeight`), so no height difference is expected. Any remaining difference surfaces as `lateGrow` plus a fault.

### `MenuSnapshotSource` — live and fixture state producers

```swift
@MainActor
protocol MenuSnapshotSource: AnyObject {
    var initialSelection: AgentProvider { get }
    func state(for selection: AgentProvider) -> MenuPanelState
    func didCommit(selection: AgentProvider)            // live: persist settings.selectedMenuProvider
    var willChange: AnyPublisher<Void, Never> { get }   // merged objectWillChange
}

final class LiveMenuSnapshotSource: MenuSnapshotSource { /* wraps QuotaViewModel; MenuContentSnapshot.live */ }
final class FixtureMenuSnapshotSource: MenuSnapshotSource { /* fixtureIndex; nextFixture() sends willChange */ }
```

### `MenuPanelModel` — the only thing SwiftUI observes

```swift
@MainActor
final class MenuPanelModel: ObservableObject {
    @Published private(set) var state: MenuPanelState
    @Published private(set) var maximumHeight: CGFloat
    init(state: MenuPanelState, maximumHeight: CGFloat) { … }
    func publish(_ next: MenuPanelState) { if next != state { state = next } }
    func updateMaximumHeight(_ height: CGFloat) { if height != maximumHeight { maximumHeight = height } }
}

struct MenuPanelRoot: View {
    @ObservedObject var model: MenuPanelModel
    let actions: MenuSurfaceActions
    let onSettledHeight: (CGFloat) -> Void

    var body: some View {
        MenuSurface(state: model.state, maximumHeight: model.maximumHeight,
                    actions: actions, onSettledHeight: onSettledHeight)
            .background(theme.windowBackground)
            .clipShape(.rect(cornerRadius: MenuPopoverTheme.shellCornerRadius))
            .overlay { /* shell outline, allowsHitTesting(false) */ }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)   // I1: top anchor
    }
}
```

### `MenuContentPipeline` — the ordering guarantee

```swift
@MainActor
final class MenuContentPipeline {
    let model: MenuPanelModel
    private let source: MenuSnapshotSource
    private let measurer = MenuSurfaceMeasurer()
    private var envelope: MenuWindowEnvelope
    private var rebuildScheduled = false
    private var isPresented = false
    private let log = Logger(subsystem: "…", category: "MenuPanel")

    /// Set by the controller; the only route to a window frame write.
    var applyHeight: (CGFloat) -> Void = { _ in }
    var appearance: () -> NSAppearance = { NSApp.effectiveAppearance }

    /// Open: measure and publish before the panel is ordered in. Returns the frame height.
    func prepareForPresentation(maximumHeight: CGFloat) -> CGFloat {
        isPresented = true
        envelope = MenuWindowEnvelope(cap: maximumHeight)
        model.updateMaximumHeight(maximumHeight)
        stage(source.state(for: model.state.selection))
        return envelope.windowHeight
    }

    func dismissed() { isPresented = false }

    /// Tab strip intent (pointer or focus + Return).
    func select(_ provider: AgentProvider) {
        guard provider != model.state.selection else { return }
        stage(source.state(for: provider))
        source.didCommit(selection: provider)
    }

    /// objectWillChange fires before the value changes, so rebuild on the next
    /// turn, coalesced, in .common modes so it also runs during scroll tracking.
    func sourceWillChange() {
        guard isPresented, !rebuildScheduled else { return }
        rebuildScheduled = true
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            guard let self else { return }
            rebuildScheduled = false
            guard isPresented else { return }
            stage(source.state(for: model.state.selection))
        }
    }

    private func stage(_ next: MenuPanelState) {
        guard next != model.state || envelope.windowHeight == 0 else { return }
        let target = measurer.height(of: next, maximumHeight: envelope.cap, appearance: appearance())
        if let grow = envelope.prepare(committing: target) { applyHeight(grow) }   // BEFORE commit
        model.publish(next)                                                        // SwiftUI commit
    }

    /// From MenuSurface.onGeometryChange.
    func surfaceDidSettle(height: CGFloat) {
        switch envelope.settle(measured: height) {
        case .unchanged: break
        case let .lateGrow(to, premeasured):
            #if DEBUG
            log.fault("Pre-measure \(premeasured) < settled \(to) for \(String(describing: self.model.state.selection))")
            #endif
            applyHeight(to)
        case let .shrink(to, generation):
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                guard let self, envelope.applyShrink(to: to, generation: generation) else { return }
                applyHeight(to)
            }
        }
    }

    func screenBudgetChanged(_ cap: CGFloat) { envelope.cap = cap; model.updateMaximumHeight(cap) }
}
```

### `MenuPanel` and `MenuPanelController`

```swift
final class MenuPanel: NSPanel {
    var onCancel: () -> Void = {}
    override var canBecomeKey: Bool { true }       // Esc and focus + Return while non-activating
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

@MainActor
final class MenuPanelController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pipeline: MenuContentPipeline
    private let router: MenuCommandRouter
    private let panel: MenuPanel
    private let hosting: NSHostingView<MenuPanelRoot>
    private var anchorTop: CGFloat = 0          // captured at present; the frame's top edge never moves
    private var presentation = 0                // generation for fade completion
    private var monitors: [Any] = []

    init(source: MenuSnapshotSource, statusLabel: MenuBarStatusLabel?) {
        // panel: styleMask [.borderless, .nonactivatingPanel], isFloatingPanel, level .popUpMenu,
        //        isOpaque false, backgroundColor .clear, hasShadow true, animationBehavior .none,
        //        becomesKeyOnlyIfNeeded false, hidesOnDeactivate false,
        //        collectionBehavior [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
        // hosting: sizingOptions [], wantsLayer, layerContentsPlacement .topLeft  (Q1 variable)
        // pipeline.applyHeight = { [weak self] in self?.setHeight($0) }
        // pipeline.appearance  = { [weak self] in self?.panel.effectiveAppearance ?? NSApp.effectiveAppearance }
        // source.willChange.sink { pipeline.sourceWillChange() }; status label updates as today
        // status button: action toggle, sendAction(on: [.leftMouseDown])
    }

    @objc private func toggle() { panel.isVisible && panel.alphaValue > 0 ? dismiss() : present() }

    private func present() {
        guard let anchor else { return }
        presentation += 1
        anchorTop = min(anchor.rect.minY, anchor.screen.visibleFrame.maxY)
        let height = pipeline.prepareForPresentation(maximumHeight: screenBudget(anchor))
        panel.setFrame(frame(height: height, anchor: anchor), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)            // no NSApp.activate: non-activating
        NSAnimationContext.runAnimationGroup { $0.duration = 0.1; panel.animator().alphaValue = 1 }
        installMonitors()
    }

    func dismiss() {
        guard panel.isVisible else { return }
        let generation = presentation
        pipeline.dismissed()
        removeMonitors()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.1; panel.animator().alphaValue = 0 }) { [weak self] in
            guard let self, presentation == generation else { return }   // reopened during fade
            panel.orderOut(nil)
        }
    }

    /// Only frame writer. Top edge fixed at anchorTop; x unchanged.
    private func setHeight(_ height: CGFloat) {
        var frame = panel.frame
        frame.origin.y = anchorTop - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func installMonitors() {
        // Global (other apps): left/right/other mouseDown → dismiss(). Observes only, so the click passes through.
        // Local (this app): mouseDown whose window is neither the panel nor the status button's window → dismiss(); return event.
    }

    func windowDidResignKey(_ notification: Notification) { dismiss() }
    // didChangeScreenParameters: re-anchor; pipeline.screenBudgetChanged(cap); setHeight(current clamp)
}
```

### `MenuCommandRouter`

```swift
@MainActor
struct MenuCommandRouter {
    let dismiss: () -> Void
    let settings: AppSettings?

    func openSettings(tab: SettingsTab) {
        dismiss()
        settings?.selectedSettingsTab = tab
        NSApp.activate()                    // required: the panel is non-activating
        // Moved from MenuPresentationController.openSettings: perform the enabled ⌘, item in
        // the application menu; otherwise show the existing "Couldn't open Settings" alert.
    }

    func quit() { dismiss(); NSApp.terminate(nil) }
}
```

## Red-first regression tests (the only new tests)

1. **`MenuPanelAnchorTests.testShellStaysTopAnchoredInTallerWindow`**
   - Host `MenuPanelRoot` (fixture state) in a borderless window whose content is 140 pt taller than the surface.
   - Assert that the scroll viewport's minY equals the header height.
   - First run it against today's unanchored `MenuTrialShell`: expected red (probe: 156 vs 86).
2. **`MenuWindowEnvelopeTests.testStaleShrinkIsDroppedAfterNewerGrow`**
   - Sequence: `prepare(600)` → `settle(600)` → `settle(400)` returns `.shrink(400, g)` → `prepare(700)` → `applyShrink(400, g)`.
   - The final `applyShrink` must return `false`, and `windowHeight` must stay ≥ 700.
   - Write it first against a policy without the generation guard (the rejected trials' resize-after-measure behavior): expected red.

Neither test is evidence about compositing. Acceptance remains the signed-app 60 fps recording in the plan's Tasks 6–7.

## Open implementation risks to watch

- **`.nonactivatingPanel` + `makeKeyAndOrderFront`:** confirm that focus + Return and Esc reach the panel while another app stays frontmost. If they don't, record it before changing activation; activation was a user decision.
- **Status item position:** a new `NSStatusItem` may appear in a different place from the `MenuBarExtra` item. Set `autosaveName` once and record the observed behavior.
- **Fade during a resize:** a grow that happens during the 0.1 s open fade is fine because opacity and frame are independent. Include an open→immediate tab click in the recording.
- **`objectWillChange` volume:** menu guardrails forbid per-second publishing. If a timer-driven publisher appears in the logs, stop and report it instead of throttling here.
