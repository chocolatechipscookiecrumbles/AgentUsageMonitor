import SwiftUI

struct CodexCreditsCard: View {
    let credits: CodexMenuPresentation.Credits

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.creditValueSpacing) {
            HStack(spacing: MenuPopoverTheme.creditHeaderSpacing) {
                Image(systemName: "creditcard")
                    .font(.system(size: MenuPopoverTheme.creditIconSize))
                    .foregroundStyle(theme.icon)

                Text("Credit Balance")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 0)

                Text(credits.balance ?? "Unavailable")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(credits.balance == nil ? theme.neutral : theme.primaryText)
            }

            if credits.availableResetCredits != nil || !credits.resetCreditExpiryDates.isEmpty {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: MenuPopoverTheme.dividerHeight)

                HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.creditHeaderSpacing) {
                    Text("Earned Reset Credits")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 0)

                    Text(availableCreditsText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(credits.availableResetCredits == nil ? theme.neutral : theme.accent)
                }

                if credits.resetCreditExpiryDates.isEmpty {
                    Text("No earned reset-credit expiry is available.")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: MenuPopoverTheme.creditExpirySpacing) {
                        ForEach(credits.resetCreditExpiryDates, id: \.self) { date in
                            Label {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        }
                    }
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

    private var availableCreditsText: String {
        guard let availableResetCredits = credits.availableResetCredits else {
            return "Unavailable"
        }
        return "\(availableResetCredits) Available"
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
