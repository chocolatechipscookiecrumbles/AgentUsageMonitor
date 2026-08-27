import SwiftUI

/// A first-run invitation, shown only while the pure `ClaudeSetupState`
/// resolver says this app has never held a Claude credential or reading.
/// Returning users keep the factual page and its recovery details.
struct ClaudeSetupOnboardingView: View {
    let connectWithSetupToken: () -> Void
    let connectWithCredentials: () -> Void

    @Environment(\.settingsAppearancePalette) private var palette

    var body: some View {
        VStack(spacing: SettingsLayoutMetrics.agentOnboardingContentSpacing) {
            AgentSettingsIcon(
                provider: .claudeCode,
                slotSize: SettingsLayoutMetrics.agentOnboardingIconSlotSize,
                artworkMaxSize: SettingsLayoutMetrics.agentOnboardingIconArtworkMaxSize
            )
            .background(
                AgentProvider.claudeCode.settingsPresentationTint.opacity(0.10),
                in: .rect(cornerRadius: SettingsLayoutMetrics.agentOnboardingIconCornerRadius)
            )

            VStack(spacing: SettingsLayoutMetrics.agentOnboardingTextSpacing) {
                Text("Set up Claude usage")
                    .font(.headline)

                Text(
                    ClaudeSetupTokenAvailability.isEnabled
                        ? "Claude Code opens sign-in and creates a long-lived token for Agent Monitor. Agent Monitor stores it in its own Keychain item and does not read Claude Code’s credential."
                        : "Connect with Claude Code credentials for live usage, or use its status line for passive capture."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: SettingsLayoutMetrics.agentOnboardingTextMaxWidth)
            }

            if ClaudeSetupTokenAvailability.isEnabled {
                Button("Connect with Claude", action: connectWithSetupToken)
                    .buttonStyle(.borderedProminent)
                    .tint(AgentProvider.claudeCode.settingsPresentationTint)
            }

            Button("Use Claude Code credentials…", action: connectWithCredentials)
                .buttonStyle(.link)

            Text(ClaudeSignInPresentation.keychainDisclosure)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: SettingsLayoutMetrics.agentOnboardingTextMaxWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SettingsLayoutMetrics.agentOnboardingHorizontalPadding)
        .padding(.vertical, SettingsLayoutMetrics.agentOnboardingVerticalPadding)
        .background(
            palette.sectionSurface,
            in: .rect(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius)
                .stroke(palette.divider, lineWidth: 0.5)
        }
    }
}
