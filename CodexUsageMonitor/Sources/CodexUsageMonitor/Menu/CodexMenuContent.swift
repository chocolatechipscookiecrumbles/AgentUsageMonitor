import SwiftUI

struct CodexMenuContent: View {
    @ObservedObject var viewModel: QuotaViewModel

    private var presentation: CodexMenuPresentation? {
        CodexMenuPresentation(
            displayState: viewModel.displayState,
            fiveHourForecast: viewModel.fiveHourForecast,
            weeklyForecast: viewModel.weeklyForecast
        )
    }

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

                if !viewModel.connectionState.isConnected {
                    CodexConnectionRecoveryCard(
                        state: viewModel.connectionState,
                        signInWithBrowser: viewModel.signInWithBrowser,
                        signInWithCLI: viewModel.signInWithCLI
                    )
                }
            } else {
                // Activity is read locally and does not depend on quota, so it
                // stays above the recovery content rather than disappearing
                // with the quota reading.
                activityCard

                CodexUnavailableContent(
                    state: viewModel.connectionState,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI
                )
            }

            if viewModel.notificationAuthorizationState == .denied {
                NotificationPermissionStrip(
                    openNotificationSettings: viewModel.openNotificationSettings
                )
            }
        }
        .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
    }

    private var activityCard: some View {
        ProviderTokenActivityCard(
            presentation: ProviderTokenActivityPresentation(
                provider: .codex,
                state: viewModel.localActivityState(for: .codex)
            )
        )
    }
}
