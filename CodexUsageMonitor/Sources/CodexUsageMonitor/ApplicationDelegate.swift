import AppKit
import SwiftUI

/// The app's composition root.
///
/// It owns the single `QuotaViewModel` — and therefore the single `AppSettings`
/// and `ProviderEnrollmentStore` — so the menu scenes, Settings, and the
/// startup tour all read and write the same state. A second settings or
/// provider model for onboarding would let the tour acknowledge itself into an
/// object nothing else observes.
@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let viewModel = QuotaViewModel()
    private lazy var startupCoordinator = StartupCoordinator(settings: viewModel.settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        if OnboardingLaunchMode.isPreview(arguments: arguments) {
            startupCoordinator.presentPreview()
            return
        }
        // The one-shot probe and popover-gate runs exit without a UI, so they
        // must not raise a window either.
        guard QuotaViewModel.shouldStartProviderMonitoring(arguments: arguments) else { return }
        startupCoordinator.startIfNeeded()
    }
}
