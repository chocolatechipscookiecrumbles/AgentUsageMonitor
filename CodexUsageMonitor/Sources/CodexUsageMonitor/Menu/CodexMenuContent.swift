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

                if let credits = presentation.credits {
                    CodexCreditsCard(credits: credits)
                }

                CodexQuotaAlertsCard(
                    alertsEnabled: viewModel.alertsEnabled,
                    authorizationState: viewModel.notificationAuthorizationState,
                    setAlertsEnabled: viewModel.setAlertsEnabled,
                    openNotificationSettings: viewModel.openNotificationSettings
                )

                if !viewModel.connectionState.isConnected {
                    CodexConnectionRecoveryCard(
                        state: viewModel.connectionState,
                        signInWithBrowser: viewModel.signInWithBrowser,
                        signInWithCLI: viewModel.signInWithCLI
                    )
                }
            } else {
                CodexUnavailableContent(
                    state: viewModel.connectionState,
                    signInWithBrowser: viewModel.signInWithBrowser,
                    signInWithCLI: viewModel.signInWithCLI
                )

                if viewModel.connectionState.isConnected {
                    CodexQuotaAlertsCard(
                        alertsEnabled: viewModel.alertsEnabled,
                        authorizationState: viewModel.notificationAuthorizationState,
                        setAlertsEnabled: viewModel.setAlertsEnabled,
                        openNotificationSettings: viewModel.openNotificationSettings
                    )
                }
            }
        }
        .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        .padding(.bottom, MenuPopoverTheme.contentBottomPadding)
    }
}
