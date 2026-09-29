import SwiftUI

/// The Claude portion of the popover, built from `ClaudeUsageDisplayModel`.
///
/// Two states: a snapshot is available (window card, plus a staleness strip
/// when the read is not live), or nothing is available yet (an explicit
/// unavailable card carrying the one user-initiated credential affordance).
/// Provenance and freshness ride in the header subtitle, so they are not
/// repeated here. No Codex credit/collector furniture appears on this tab.
struct ClaudeMenuContent: View {
    @ObservedObject var viewModel: QuotaViewModel
    /// Observed separately from the view model so a Token Monitor preference
    /// change redraws an open popover.
    @ObservedObject var settings: AppSettings

    @Environment(\.colorScheme) private var colorScheme

    private var model: ClaudeUsageDisplayModel? {
        viewModel.claudeState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) }
    }

    var body: some View {
        VStack(spacing: MenuPopoverTheme.contentSpacing) {
            if let model {
                if let staleness = monitoringStatus.detail ?? model.stalenessNotice {
                    ClaudeStalenessStrip(notice: staleness)
                }

                ClaudeUsageWindowCard(model: model)

                activityCard

                // Provenance lives here rather than the header so the freshness
                // line stays identical across providers; it names where the
                // reading came from (OAuth, capture, or cache).
                Text("\(monitoringStatus.text) · Read from: \(model.sourceLabel)")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

            } else {
                // Activity is read locally and does not depend on quota, so it
                // stays above the recovery content rather than disappearing
                // with the quota reading.
                activityCard

                ClaudeUnavailableContent(
                    connectionState: viewModel.claudeConnectionState,
                    statusDetail: monitoringStatus.detail,
                    connect: viewModel.connectClaude
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

    private var monitoringStatus: ClaudeConnectionStatus {
        ClaudeConnectionStatus.resolve(
            isEnrolled: viewModel.enrollment.isEnabled(.claudeCode),
            signInState: viewModel.claudeConnectionState,
            usageState: viewModel.claudeState
        )
    }

    @ViewBuilder
    private var activityCard: some View {
        if settings.isTokenMonitorVisible(for: .claudeCode) {
            ProviderTokenActivityCard(
                presentation: ProviderTokenActivityPresentation(
                    provider: .claudeCode,
                    state: viewModel.localActivityState(for: .claudeCode),
                    range: settings.tokenMonitorRange(for: .claudeCode)
                ),
                visibleSections: settings.enabledTokenMonitorSections(for: .claudeCode)
            )
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
