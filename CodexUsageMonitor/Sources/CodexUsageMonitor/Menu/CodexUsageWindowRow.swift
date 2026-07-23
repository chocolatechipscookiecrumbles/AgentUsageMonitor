import SwiftUI

struct CodexUsageWindowRow: View {
    let window: CodexMenuPresentation.Window

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch window.value {
        case .available(let usedPercent, let resetAt):
            VStack(alignment: .leading, spacing: MenuPopoverTheme.windowRowSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.windowRowSpacing) {
                    Text(window.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 0)

                    Text("\(usedPercent)% used")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.quotaTint(forRemainingPercent: 100 - usedPercent))
                }

                UsageProgressBar(
                    usedPercent: usedPercent,
                    accessibilityLabel: "\(window.title) usage"
                )

                HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.windowRowFooterSpacing) {
                    Text("Remaining \(100 - usedPercent)%")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Spacer(minLength: MenuPopoverTheme.windowRowFooterSpacing)

                    Text(MenuResetTimingPresentation(resetAt: resetAt).text)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }

                if let forecast = window.forecast {
                    Text(CodexForecastPresentation(forecast: forecast).text)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, MenuPopoverTheme.forecastTopSpacing)
                }
            }
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: MenuPopoverTheme.windowRowFooterSpacing) {
                Text(window.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(theme.neutral)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
