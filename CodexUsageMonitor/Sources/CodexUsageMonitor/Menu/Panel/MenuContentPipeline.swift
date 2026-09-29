import AppKit
import OSLog
import SwiftUI

/// Measures a surface state offscreen with the same view, width and layout as
/// the live panel. `MenuViewportLayout` makes this a single pass; inert actions
/// keep it free of side effects.
@MainActor
final class MenuSurfaceMeasurer {
    private let host = NSHostingView(rootView: MenuSurface(
        state: .placeholder(), maximumHeight: 0, actions: .inert
    ))

    func height(of state: MenuPanelState, maximumHeight: CGFloat, appearance: NSAppearance) -> CGFloat {
        host.appearance = appearance
        host.rootView = MenuSurface(state: state, maximumHeight: maximumHeight, actions: .inert)
        host.layoutSubtreeIfNeeded()
        return ceil(host.fittingSize.height)
    }
}

/// Orders every content change against the window (ADR 0004): build the next
/// state, pre-measure it, grow the window if needed, then publish, all in one
/// main-thread turn. The window shrinks only after the live surface settles.
@MainActor
final class MenuContentPipeline {
    let model: MenuPanelModel
    /// The only route to a window frame write; set by the panel controller.
    var applyHeight: (CGFloat) -> Void = { _ in }
    var appearance: () -> NSAppearance = { NSApp.effectiveAppearance }

    private let source: MenuSnapshotSource
    private let measurer = MenuSurfaceMeasurer()
    private var envelope = MenuWindowEnvelope(cap: MenuPopoverTheme.maximumPopoverHeight)
    private var rebuildScheduled = false
    private(set) var isPresented = false
    private let log = Logger(subsystem: "com.david.codex-usage-monitor", category: "MenuPanel")

    init(source: MenuSnapshotSource) {
        self.source = source
        model = MenuPanelModel(
            state: source.state(for: source.initialSelection),
            maximumHeight: MenuPopoverTheme.maximumPopoverHeight
        )
    }

    var selection: AgentProvider { model.state.selection }

    /// Measures and publishes the current state before the panel is ordered in.
    /// Returns the window height to open at.
    func prepareForPresentation(maximumHeight: CGFloat) -> CGFloat {
        isPresented = true
        envelope = MenuWindowEnvelope(cap: maximumHeight)
        model.updateMaximumHeight(maximumHeight)
        stage(source.state(for: selection))
        return envelope.windowHeight
    }

    func dismissed() {
        isPresented = false
    }

    /// Tab strip intent, from a pointer click or focus + Return.
    func select(_ provider: AgentProvider) {
        let provider = MenuPopoverProviderCatalog.resolvedSelection(provider)
        guard provider != selection else { return }
        source.select(provider)
        stage(source.state(for: provider))
    }

    /// `objectWillChange` fires before the value changes, so rebuild on the
    /// next turn, coalescing a burst of changes into one measurement.
    func sourceWillChange() {
        guard isPresented, !rebuildScheduled else { return }
        rebuildScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            rebuildScheduled = false
            guard isPresented else { return }
            stage(source.state(for: selection))
        }
    }

    /// Reported by the live surface after SwiftUI lays it out.
    func surfaceDidSettle(height: CGFloat) {
        guard isPresented else { return }
        switch envelope.settle(measured: height) {
        case .unchanged:
            break
        case let .lateGrow(to, premeasured):
            #if DEBUG
            log.fault("Menu pre-measure \(premeasured, privacy: .public) < settled \(to, privacy: .public) for \(self.selection.rawValue, privacy: .public)")
            #endif
            applyHeight(to)
        case let .shrink(to, generation):
            DispatchQueue.main.async { [weak self] in
                guard let self, isPresented,
                      envelope.applyShrink(to: to, generation: generation) else { return }
                applyHeight(to)
            }
        }
    }

    private func stage(_ next: MenuPanelState) {
        let target = measurer.height(of: next, maximumHeight: envelope.cap, appearance: appearance())
        if let grow = envelope.prepare(committing: target) {
            applyHeight(grow)   // before the SwiftUI commit (ADR 0004 I2)
        }
        model.publish(next)
    }
}
