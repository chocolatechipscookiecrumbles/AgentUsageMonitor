import Combine
import Foundation

/// Owns which tour page is showing, and nothing else.
///
/// No AppKit, no provider service, no Keychain, no network, and no persistence:
/// acknowledgement is the coordinator's job, so this type stays testable and
/// cannot accidentally acquire a side effect on a provider.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var currentPageIndex = 0

    let pages: [OnboardingPage]
    /// Fired for Skip, the window's close button, and the final page's Dismiss.
    /// All three mean the same thing, so the coordinator has one path to make
    /// idempotent rather than three.
    private let onAcknowledge: () -> Void

    init(
        pages: [OnboardingPage] = OnboardingPage.all,
        onAcknowledge: @escaping () -> Void
    ) {
        self.pages = pages
        self.onAcknowledge = onAcknowledge
    }

    var currentPage: OnboardingPage {
        pages[min(currentPageIndex, pages.count - 1)]
    }

    var canGoBack: Bool { currentPageIndex > 0 }
    var canGoForward: Bool { currentPageIndex < pages.count - 1 }

    func goBack() {
        guard canGoBack else { return }
        currentPageIndex -= 1
    }

    func goForward() {
        guard canGoForward else { return }
        currentPageIndex += 1
    }

    func dismiss() {
        onAcknowledge()
    }
}
