import SwiftUI

struct CodexDisconnectedMenuView: View {
    let state: AgentConnectionState
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void

    var body: some View {
        Text(title)
        if let detail {
            Text(detail)
                .font(.caption)
                .foregroundStyle(detailColor)
        }
        if state != .checking {
            Divider()
            Button("Sign in with browser", action: signInWithBrowser)
                .disabled(signInDisabled)
            Button("Sign in with Codex CLI…", action: signInWithCLI)
                .disabled(signInDisabled)
        }
    }

    private var title: String {
        switch state {
        case .checking:
            "Checking Codex connection…"
        case .missingCLI:
            "Codex CLI not found"
        case .disconnected:
            "Codex isn’t connected"
        case .signingIn(let method):
            "Signing in with \(method.displayName)…"
        case .failed:
            "Codex connection needs attention"
        case .connected:
            "Codex connected"
        }
    }

    private var detail: String? {
        switch state {
        case .checking, .connected:
            nil
        case .missingCLI:
            "Install the Codex CLI, then reopen the app to connect your account."
        case .disconnected:
            "Sign in to show current five-hour and weekly usage."
        case .signingIn(.browser):
            "Finish signing in in your browser."
        case .signingIn(.cli):
            "Finish signing in in the Terminal window."
        case .failed(let failure):
            failure.displayMessage
        }
    }

    private var detailColor: Color {
        if case .failed = state { return .orange }
        return .secondary
    }

    private var signInDisabled: Bool {
        switch state {
        case .missingCLI, .signingIn, .checking, .connected:
            true
        case .disconnected, .failed:
            false
        }
    }
}
