import SwiftUI

struct AgentSettingsIcon: View {
    let provider: AgentProvider
    let size: CGFloat

    var body: some View {
        Image(provider == .codex ? "codex-agent" : "claude-code-agent", bundle: .main)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
