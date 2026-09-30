import AppKit
import Combine
import SwiftUI

/// Owns the content-fitted menu panel (ADR 0004): the status item, the panel,
/// presentation, dismissal and the only writes to the panel's frame.
@MainActor
final class MenuPanelController: NSObject, NSWindowDelegate {
    private let viewModel: QuotaViewModel?
    private let source: MenuSnapshotSource
    private let pipeline: MenuContentPipeline
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuPanel()
    private var hosting: NSHostingView<MenuPanelRoot>!
    private var labelHost: MenuStatusHostingView<MenuBarStatusLabel>?
    private var router: MenuCommandRouter!
    /// The frame's top edge; captured on open so resizing never moves it.
    private var anchorTop: CGFloat = 0
    private var isPresented = false
    /// Advanced on every open so a fade-out from an earlier close cannot hide
    /// a panel that was reopened during the fade.
    private var presentation = 0
    private var monitors: [Any] = []
    private var subscriptions = Set<AnyCancellable>()

    static let fadeDuration: TimeInterval = 0.1

    /// Pass nil for the synthetic fixture replay; no live model is built.
    init(viewModel: QuotaViewModel?) {
        self.viewModel = viewModel
        source = viewModel.map { LiveMenuSnapshotSource(viewModel: $0) } ?? FixtureMenuSnapshotSource()
        pipeline = MenuContentPipeline(source: source)
        super.init()
        router = MenuCommandRouter(dismiss: { [weak self] in self?.dismiss() }, settings: viewModel?.settings)

        hosting = NSHostingView(rootView: MenuPanelRoot(
            model: pipeline.model,
            actions: makeActions(),
            onSettledHeight: { [weak self] in self?.pipeline.surfaceDidSettle(height: $0) }
        ))
        // The controller sizes the window; the hosting view must not.
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        hosting.layerContentsPlacement = .topLeft
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.dismiss() }

        pipeline.applyHeight = { [weak self] in self?.setHeight($0) }
        pipeline.appearance = { [weak self] in self?.panel.effectiveAppearance ?? NSApp.effectiveAppearance }
        source.willChange
            .sink { [weak self] in self?.pipeline.sourceWillChange() }
            .store(in: &subscriptions)

        configureStatusItem()
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.screenParametersChanged() }
            .store(in: &subscriptions)
    }

    private func makeActions() -> MenuSurfaceActions {
        MenuSurfaceActions(
            select: { [weak self] in self?.pipeline.select($0) },
            refresh: { [weak self] in
                guard let self else { return }
                source.refresh(pipeline.selection)
            },
            connect: { [weak self] in
                guard let self else { return }
                source.connect(pipeline.selection)
            },
            signInWithBrowser: { [weak self] in self?.source.signInWithBrowser() },
            signInWithCLI: { [weak self] in self?.source.signInWithCLI() },
            openSystemNotificationSettings: { [weak self] in self?.source.openSystemNotificationSettings() },
            openNotificationSettings: { [weak self] in self?.router.openSettings(tab: .notifications) },
            openPreferences: { [weak self] in self?.router.openSettings(tab: .general) },
            nextFixture: { [weak self] in self?.source.nextFixture() },
            quit: { [weak self] in self?.router.quit() },
            dismiss: { [weak self] in self?.dismiss() }
        )
    }

    // MARK: Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(toggle)
        guard let viewModel else {
            button.title = "Panel Demo"
            button.setAccessibilityLabel(button.title)
            return
        }
        let label = MenuStatusHostingView(rootView: MenuBarStatusLabel(viewModel: viewModel))
        label.setAccessibilityElement(false)
        button.addSubview(label)
        labelHost = label
        viewModel.objectWillChange.merge(with: viewModel.settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }
            .store(in: &subscriptions)
        updateLabel()
    }

    private func updateLabel() {
        guard let label = labelHost, let button = statusItem.button, let model = viewModel else { return }
        let size = label.fittingSize
        statusItem.length = ceil(size.width) + 12
        label.frame = NSRect(x: 6, y: (button.bounds.height - size.height) / 2,
                             width: size.width, height: size.height)
        let presentation = MenuBarLabelPresentation(provider: model.effectiveMenuBarProvider,
            codexDisplayState: model.displayState, claudeState: model.claudeState,
            style: model.settings.menuBarDisplayStyle, valueMode: model.settings.quotaValueMode,
            showsProviderMarker: MenuBarProviderSelection.showsSelector(eligible: model.menuBarEligibleProviders))
        if model.settings.menuBarDisplayStyle.isGraphical {
            button.setAccessibilityLabel(MenuBarQuotaBars.providers(
                codexDisplayState: model.displayState, claudeState: model.claudeState
            ).map(\.accessibilityDescription).joined(separator: ". "))
        } else {
            button.setAccessibilityLabel(presentation.accessibilityLabel)
        }
    }

    // MARK: Presentation

    @objc private func toggle() {
        isPresented ? dismiss() : present()
    }

    private func present() {
        guard let anchor else { return }
        presentation += 1
        isPresented = true
        let screen = anchor.screen.visibleFrame
        anchorTop = min(anchor.rect.minY, screen.maxY)
        let budget = max(0, min(MenuPopoverTheme.maximumPopoverHeight, anchorTop - screen.minY - 8))
        let height = pipeline.prepareForPresentation(maximumHeight: budget)
        let width = MenuPopoverTheme.popoverWidth
        let x = min(max(anchor.rect.midX - width / 2, screen.minX), screen.maxX - width)
        panel.setFrame(NSRect(x: x, y: anchorTop - height, width: width, height: height), display: false)
        panel.alphaValue = 0
        // Non-activating: the frontmost app keeps focus; the panel takes keys.
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        pipeline.dismissed()
        removeMonitors()
        let closing = presentation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentation == closing, !self.isPresented else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    /// The only frame writer. The top edge stays at `anchorTop`.
    private func setHeight(_ height: CGFloat) {
        var frame = panel.frame
        frame.origin.y = anchorTop - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private var anchor: (rect: NSRect, screen: NSScreen)? {
        guard let button = statusItem.button, let window = button.window,
              let screen = window.screen else { return nil }
        return (window.convertToScreen(button.convert(button.bounds, to: nil)), screen)
    }

    /// A display change can move or remove the status item's screen; close
    /// rather than keep a panel anchored to stale geometry.
    private func screenParametersChanged() {
        updateLabel()
        dismiss()
    }

    // MARK: Dismissal

    private func installMonitors() {
        removeMonitors()
        // Clicks in other apps only close the menu; a global monitor observes
        // and never consumes, so the click still reaches its target.
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in self?.dismiss() }
        ) {
            monitors.append(global)
        }
        // Clicks in this app's other windows; the status button toggles itself.
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] event in
                guard let self else { return event }
                if event.window !== panel, event.window !== statusItem.button?.window {
                    dismiss()
                }
                return event
            }
        ) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }
}
