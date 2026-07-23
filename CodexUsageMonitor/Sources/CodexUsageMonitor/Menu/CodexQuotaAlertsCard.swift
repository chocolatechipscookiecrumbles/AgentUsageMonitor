import SwiftUI

struct CodexQuotaAlertsCard: View {
    let alertsEnabled: Bool
    let authorizationState: NotificationAuthorizationState
    let setAlertsEnabled: (Bool) -> Void
    let openNotificationSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlSpacing) {
            Toggle("Quota alerts", isOn: alertsBinding)
                .font(.callout.weight(.medium))
                .toggleStyle(.switch)

            if authorizationState == .denied {
                VStack(alignment: .leading, spacing: MenuPopoverTheme.compactControlTextSpacing) {
                    Text("Notifications are disabled in System Settings.")
                        .font(.caption)
                        .foregroundStyle(theme.warning)

                    Button("Open System Notification Settings", action: openNotificationSettings)
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
    }

    private var alertsBinding: Binding<Bool> {
        Binding(
            get: { alertsEnabled },
            set: { newValue in
                setAlertsEnabled(newValue)
            }
        )
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
