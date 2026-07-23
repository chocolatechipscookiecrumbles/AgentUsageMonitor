import SwiftUI

/// The two co-equal Claude credential methods presented side by side, the
/// direct counterpart of Codex's browser/CLI sign-in pair.
///
/// Neither method is a default: the user chooses, so the Keychain ACL grant
/// in "Use Claude Code credentials…" is always an explicit, disclosed action.
struct ClaudeSignInView: View {
    let state: ClaudeConnectionState
    let activeMethod: ClaudeSignInMethod?
    let signInWithBrowser: () -> Void
    let useClaudeCodeCredentials: () -> Void
    let signOut: () -> Void

    private var presentation: ClaudeSignInPresentation {
        ClaudeSignInPresentation.make(state: state, activeMethod: activeMethod)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.title)
            if let detail = presentation.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(detailColor)
            }

            if presentation.showsSignOut {
                Button("Sign out of Claude", action: signOut)
            } else if state != .checking {
                Divider()
                Button("Sign in with browser", action: signInWithBrowser)
                    .disabled(presentation.signInDisabled || state == .missingCLI)
                Text("Uses Claude’s own sign-in to issue a token for this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Use Claude Code credentials…", action: useClaudeCodeCredentials)
                    .disabled(presentation.signInDisabled)
                Text(ClaudeSignInPresentation.keychainDisclosure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailColor: Color {
        if case .failed = state { return .orange }
        return .secondary
    }
}
