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

    @Environment(\.colorScheme) private var colorScheme

    private var model: ClaudeUsageDisplayModel? {
        viewModel.claudeState.presentation.map { ClaudeUsageDisplayModel(presentation: $0) }
    }

    var body: some View {
        VStack(spacing: MenuPopoverTheme.contentSpacing) {
            if let model {
                if let staleness = model.stalenessNotice {
                    ClaudeStalenessStrip(notice: staleness)
                }

                ClaudeUsageWindowCard(model: model)

                // Provenance lives here rather than the header so the freshness
                // line stays identical across providers; it names where the
                // reading came from (OAuth, capture, or cache).
                Text("Read from: \(model.sourceLabel)")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Passive capture is a legitimate source that needs no
                // connection, so a merely-not-connected state is normal and
                // shows no recovery card. Only an actively failed connection
                // warrants offering the credential affordance alongside the
                // last result.
                if case .failed = viewModel.claudeConnectionState {
                    ClaudeConnectionRecoveryCard(
                        state: viewModel.claudeConnectionState,
                        connectWithCredentials: viewModel.connectClaudeWithCredentials
                    )
                }
            } else {
                ClaudeUnavailableContent(
                    connectionState: viewModel.claudeConnectionState,
                    connectWithCredentials: viewModel.connectClaudeWithCredentials
                )
            }

            if viewModel.notificationAuthorizationState == .denied {
                NotificationPermissionStrip(
                    openNotificationSettings: viewModel.openNotificationSettings
                )
            }
        }
        .padding(.horizontal, MenuPopoverTheme.contentHorizontalPadding)
        .padding(.bottom, MenuPopoverTheme.contentBottomPadding)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
