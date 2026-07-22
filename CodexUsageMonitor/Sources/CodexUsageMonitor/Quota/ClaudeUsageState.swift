import Foundation

/// What the Claude surface can show. `unavailable` carries a reason so the UI
/// can be specific about *why* there is no number, rather than rendering
/// zeros — the explicit not-available fallback the capability gate requires.
enum ClaudeUsageState: Sendable {
    case unavailable(reason: String)
    case available(ClaudeUsagePresentation)

    static let notConnectedReason =
        "Claude usage unavailable — connect Claude Code credentials, or enable passive capture."

    var presentation: ClaudeUsagePresentation? {
        if case .available(let presentation) = self { return presentation }
        return nil
    }

    var isAvailable: Bool { presentation != nil }
}
