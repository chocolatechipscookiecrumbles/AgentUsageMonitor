import SwiftUI

struct ClaudeSignInView: View {
    let state: ClaudeConnectionState
    let connect: () -> Void
    let disconnect: () -> Void

    private var presentation: ClaudeSignInPresentation {
        ClaudeSignInPresentation.make(state: state)
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
                Button("Disconnect Claude", action: disconnect)
            } else if state != .checking {
                Divider()
                Button("Connect Claude", action: connect)
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
