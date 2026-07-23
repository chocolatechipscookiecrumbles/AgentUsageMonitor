import SwiftUI

/// One Claude usage window — a live figure or an explicit unavailable line —
/// matching `CodexUsageWindowRow`'s shape. The optional footnote carries the
/// weekly shared-pool caveat under a real figure.
struct ClaudeUsageWindowRow: View {
    enum Value {
        case figure(usedPercent: Int, resetsAt: Date?)
        case unavailable(message: String)
    }

    let title: String
    let value: Value
    let footnote: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch value {
        case .figure(let usedPercent, let resetsAt):
            VStack(alignment: .leading, spacing: MenuPopoverTheme.windowRowSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.windowRowSpacing) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 0)

                    Text("\(usedPercent)% used")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.quotaTint(forRemainingPercent: 100 - usedPercent))
                }

                UsageProgressBar(
                    usedPercent: usedPercent,
                    accessibilityLabel: "\(title) usage"
                )

                HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.windowRowFooterSpacing) {
                    Text("Remaining \(100 - usedPercent)%")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Spacer(minLength: MenuPopoverTheme.windowRowFooterSpacing)

                    Text(MenuResetTimingPresentation(resetAt: resetsAt).text)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }

                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(MenuPopoverTheme.maximumSupportingLines)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, MenuPopoverTheme.forecastTopSpacing)
                }
            }
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: MenuPopoverTheme.windowRowFooterSpacing) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(theme.neutral)
                    .fixedSize(horizontal: false, vertical: true)

                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(MenuPopoverTheme.maximumSupportingLines)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
