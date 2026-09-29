import SwiftUI

struct CodexMenuContent: View {
    @ObservedObject var viewModel: QuotaViewModel
    /// Observed separately from the view model so a Token Monitor preference
    /// change redraws an open popover.
    @ObservedObject var settings: AppSettings

    private var presentation: CodexMenuPresentation? {
        CodexMenuPresentation(
            displayState: viewModel.displayState,
            fiveHourForecast: viewModel.fiveHourForecast,
            weeklyForecast: viewModel.weeklyForecast
        )
    }

    var body: some View {
        CodexMenuContentRender(
            presentation: presentation,
            connectionState: viewModel.connectionState,
            activity: settings.isTokenMonitorVisible(for: .codex)
                ? ProviderTokenActivityPresentation(
                    provider: .codex,
                    state: viewModel.localActivityState(for: .codex),
                    range: settings.tokenMonitorRange(for: .codex)
                ) : nil,
            visibleActivitySections: settings.enabledTokenMonitorSections(for: .codex),
            showsNotificationPermission: viewModel.notificationAuthorizationState == .denied,
            signInWithBrowser: viewModel.signInWithBrowser,
            signInWithCLI: viewModel.signInWithCLI,
            openSystemNotificationSettings: viewModel.openNotificationSettings
        )
    }
}

struct CodexMenuContentRender: View {
    let presentation: CodexMenuPresentation?
    let connectionState: AgentConnectionState
    let activity: ProviderTokenActivityPresentation?
    let visibleActivitySections: Set<TokenMonitorSection>
    let showsNotificationPermission: Bool
    let signInWithBrowser: () -> Void
    let signInWithCLI: () -> Void
    let openSystemNotificationSettings: () -> Void

    var body: some View {
        VStack(spacing: MenuPopoverTheme.contentSpacing) {
            if let presentation {
                if presentation.isCached {
                    CodexCachedWarningStrip()
                }

                CodexUsageWindowCard(
                    windows: presentation.windows,
                    isCached: presentation.isCached
                )

                activityCard

                if let credits = presentation.credits {
                    CodexCreditsCard(credits: credits)
                }

                if !connectionState.isConnected {
                    CodexConnectionRecoveryCard(
                        state: connectionState,
                        signInWithBrowser: signInWithBrowser,
                        signInWithCLI: signInWithCLI
                    )
                }
            } else {
                // Activity is read locally and does not depend on quota, so it
                // stays above the recovery content rather than disappearing
                // with the quota reading.
                activityCard

                CodexUnavailableContent(
                    state: connectionState,
                    signInWithBrowser: signInWithBrowser,
                    signInWithCLI: signInWithCLI
                )
            }

            if showsNotificationPermission {
                NotificationPermissionStrip(
                    openNotificationSettings: openSystemNotificationSettings
                )
            }
        }
        .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
    }

    @ViewBuilder
    private var activityCard: some View {
        if let activity {
            ProviderTokenActivityCard(
                presentation: activity,
                visibleSections: visibleActivitySections
            )
        }
    }
}
