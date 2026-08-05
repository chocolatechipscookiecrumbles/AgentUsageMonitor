import AppKit
import SwiftUI

/// Owns the one first-run window and its acknowledgement lifecycle.
///
/// Presentation only: it never touches a provider, a credential, or enrollment.
/// The window controller is retained for the whole tour, because an
/// `NSWindowController` that goes out of scope takes its window with it.
@MainActor
final class StartupCoordinator: NSObject {
    private let settings: AppSettings
    private var windowController: NSWindowController?
    /// True while the preview flag is driving presentation: the tour is shown
    /// for visual acceptance and must not record acknowledgement.
    private var isPreviewing = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Normal launch. Shows the tour only when this installation has not
    /// acknowledged the current version, so a relaunch after any dismissal
    /// stays silent.
    func startIfNeeded() {
        guard settings.needsOnboarding else { return }
        present(isPreview: false)
    }

    /// Visual-acceptance launch. Always presents, never persists.
    func presentPreview() {
        present(isPreview: true)
    }

    private func present(isPreview: Bool) {
        guard windowController == nil else {
            windowController?.window?.makeKeyAndOrderFront(nil)
            return
        }
        isPreviewing = isPreview

        let viewModel = OnboardingViewModel { [weak self] in
            self?.acknowledgeAndClose()
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: OnboardingView.contentWidth,
                height: OnboardingView.contentHeight
            ),
            // Titled and closable so the window has a real close button: the
            // tour must be dismissible without reading any instruction.
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Agent Monitor"
        window.contentView = NSHostingView(rootView: OnboardingView(viewModel: viewModel))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        // This is an LSUIElement app, so activating brings the tour forward
        // without adding a Dock item.
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    /// The one acknowledgement path. Skip, the close button, and Dismiss all
    /// arrive here, and `acknowledgeCurrentOnboarding()` is itself idempotent,
    /// so the version can only be written once.
    private func acknowledgeAndClose() {
        acknowledge()
        windowController?.close()
        windowController = nil
    }

    private func acknowledge() {
        guard !isPreviewing else { return }
        settings.acknowledgeCurrentOnboarding()
    }
}

extension StartupCoordinator: NSWindowDelegate {
    /// Closing the window is a dismissal like any other: it records
    /// acknowledgement and changes no provider's enrollment.
    func windowWillClose(_ notification: Notification) {
        acknowledge()
        windowController = nil
    }
}
