import SwiftUI

/// Claude's five-hour and weekly windows in one card, matching the Codex
/// window card's layout so both tabs read as one system.
///
/// A window that has already reset, or is missing, is never shown as a live
/// figure (gate criterion #5): rendering a percentage there would invent a
/// quota. The weekly row carries the shared-pool caveat whenever it shows a
/// real figure.
struct ClaudeUsageWindowCard: View {
    let model: ClaudeUsageDisplayModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ClaudeUsageWindowRow(
                title: "Five Hour Window",
                value: fiveHourValue,
                footnote: nil
            )
            .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
            .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)

            Rectangle()
                .fill(theme.divider)
                .frame(height: MenuPopoverTheme.dividerHeight)
                .padding(.horizontal, MenuPopoverTheme.windowRowDividerInset)

            ClaudeUsageWindowRow(
                title: "Weekly Window",
                value: weeklyValue,
                footnote: weeklyFootnote
            )
            .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
            .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        }
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
        .opacity(model.stalenessNotice == nil ? 1 : 0.75)
    }

    private var fiveHourValue: ClaudeUsageWindowRow.Value {
        // The session note is the only correct explanation when the window
        // has not begun, and only when the data is live enough to rule out
        // the other reasons `fiveHour == nil` conflates.
        let unavailableMessage = ClaudeUsageDisplayModel.showsFiveHourSessionNote(
            isConnected: model.isLive,
            hasFiveHourWindow: model.fiveHour != nil
        ) ? ClaudeUsageDisplayModel.fiveHourSessionNote : "Usage unavailable"
        return windowValue(model.fiveHour, unavailableMessage: unavailableMessage)
    }

    private var weeklyValue: ClaudeUsageWindowRow.Value {
        windowValue(model.sevenDay, unavailableMessage: "Usage unavailable")
    }

    private var weeklyFootnote: String? {
        if case .figure = weeklyValue {
            return ClaudeUsageDisplayModel.weeklyScopeCaveat
        }
        return nil
    }

    private func windowValue(
        _ window: ClaudeUsageDisplayModel.Window?,
        unavailableMessage: String
    ) -> ClaudeUsageWindowRow.Value {
        guard let window else {
            return .unavailable(message: unavailableMessage)
        }
        if window.hasReset {
            return .unavailable(message: window.resetNote ?? "This window has since reset.")
        }
        return .figure(usedPercent: window.usedPercent, resetsAt: window.resetsAt)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
