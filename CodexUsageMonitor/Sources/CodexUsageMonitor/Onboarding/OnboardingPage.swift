import Foundation

/// One page of the first-run tour.
///
/// The tour is educational, not a setup wizard: no page performs a network,
/// Keychain, CLI, or provider operation, and finishing it connects nothing.
struct OnboardingPage: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    /// Name of the imageset in the app's asset catalog. Artwork is supplied out
    /// of band (the catalog is not tracked in the public repository), so the
    /// view renders the page without it rather than shipping a placeholder that
    /// could be mistaken for final art.
    let assetName: String
    /// Read by VoiceOver in place of the artwork. Required: an unlabeled
    /// decorative image is not acceptable in a shipped tour.
    let imageAccessibilityDescription: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome",
            title: "Welcome to Agent Monitor",
            body: "Keep Codex and Claude usage one click away in the menu bar.",
            assetName: "OnboardingWelcome",
            imageAccessibilityDescription: "The Agent Monitor menu-bar popover showing Codex and Claude usage."
        ),
        OnboardingPage(
            id: "providers",
            title: "Connect only what you use",
            body: "Codex and Claude start disconnected. Connect each provider separately when you’re ready.",
            assetName: "OnboardingProviders",
            imageAccessibilityDescription: "The Codex and Claude tabs, each showing its own Connect button."
        ),
        OnboardingPage(
            id: "privacy",
            title: "Local and private",
            body: "Token Monitor reads supported usage fields on this Mac. It does not collect prompts or responses.",
            assetName: "OnboardingPrivacy",
            imageAccessibilityDescription: "A Mac reading local usage totals, with prompts and responses left untouched."
        ),
    ]
}

/// The visual-acceptance entry point: re-opens the tour in the signed app
/// without writing acknowledgement, changing enrollment, or starting any
/// provider monitoring.
enum OnboardingLaunchMode {
    static let previewArgument = "--show-onboarding-preview"

    static func isPreview(arguments: [String]) -> Bool {
        arguments.contains(previewArgument)
    }
}
