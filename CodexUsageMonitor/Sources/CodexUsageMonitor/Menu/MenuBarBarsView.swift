import SwiftUI

/// Dimensions for the graphical menu-bar indicators. Width is deliberately tight
/// (menu-bar real estate is scarce and shared with system + third-party items).
enum MenuBarBarMetrics {
    /// Total block width; also each bar's track width. Fixed so the menu-bar
    /// item never resizes as fills change on refresh.
    static let trackWidth: CGFloat = 22

    // Option 1 — stacked (four thin bars).
    static let stackedBarHeight: CGFloat = 2
    static let stackedWithinPairSpacing: CGFloat = 1.5
    static let stackedCornerRadius: CGFloat = 1

    // Option 2 — combined (weekly full-height background, five-hour inset).
    static let combinedTrackHeight: CGFloat = 6
    static let combinedInsetHeight: CGFloat = 3.5
    static let combinedTrackCornerRadius: CGFloat = 1.5
    static let combinedInsetCornerRadius: CGFloat = 1

    static let betweenProviderSpacing: CGFloat = 3
    /// A near-empty (but non-unavailable) window still shows a sliver.
    static let minimumVisibleFill: CGFloat = 2

    static let weeklyOpacity: CGFloat = 0.4
    static let trackOpacity: CGFloat = 0.18
    /// Cached/passive data dims the whole provider row.
    static let staleOpacity: CGFloat = 0.5

    /// Leading fill width for a normalized remaining value, with the sliver
    /// floor; a genuine 0% and `unavailable` both render no fill (empty track).
    static func fillWidth(_ remaining: Double?) -> CGFloat {
        guard let remaining, remaining > 0 else { return 0 }
        return max(minimumVisibleFill, trackWidth * CGFloat(remaining))
    }
}

/// Renders the `.stackedBars` / `.combinedBars` menu-bar modes from the pure
/// `MenuBarQuotaBars` model. No text; a single combined accessibility label.
struct MenuBarBarsView: View {
    let style: MenuBarDisplayStyle
    let providers: [MenuBarQuotaBars]

    var body: some View {
        VStack(alignment: .leading, spacing: MenuBarBarMetrics.betweenProviderSpacing) {
            ForEach(providers, id: \.provider) { provider in
                row(for: provider)
                    .opacity(rowOpacity(provider))
            }
        }
        .frame(width: MenuBarBarMetrics.trackWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(providers.map(\.accessibilityDescription).joined(separator: ". "))
    }

    @ViewBuilder
    private func row(for provider: MenuBarQuotaBars) -> some View {
        let tint = provider.provider.settingsPresentationTint
        switch style {
        case .stackedBars, .gaugeAndLowest, .fiveHourAndWeekly:
            // gauge/text cases are unreachable here (the label view handles them)
            // but keep the switch exhaustive; treat as stacked.
            VStack(alignment: .leading, spacing: MenuBarBarMetrics.stackedWithinPairSpacing) {
                bar(fill: provider.fiveHour, color: tint,
                    height: MenuBarBarMetrics.stackedBarHeight,
                    radius: MenuBarBarMetrics.stackedCornerRadius, tint: tint)
                bar(fill: provider.weekly, color: tint.opacity(MenuBarBarMetrics.weeklyOpacity),
                    height: MenuBarBarMetrics.stackedBarHeight,
                    radius: MenuBarBarMetrics.stackedCornerRadius, tint: tint)
            }
        case .combinedBars:
            combinedBar(provider: provider, tint: tint)
        }
    }

    /// A single leading-anchored fill over a faint full-width track.
    private func bar(fill: MenuBarQuotaBars.Fill, color: Color, height: CGFloat, radius: CGFloat, tint: Color) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: radius)
                .fill(tint.opacity(MenuBarBarMetrics.trackOpacity))
                .frame(width: MenuBarBarMetrics.trackWidth, height: height)
            RoundedRectangle(cornerRadius: radius)
                .fill(color)
                .frame(width: MenuBarBarMetrics.fillWidth(fill.normalizedRemaining), height: height)
        }
        .frame(width: MenuBarBarMetrics.trackWidth, height: height, alignment: .leading)
    }

    /// Weekly = full-height, lower-opacity background; five-hour = inset
    /// (shorter, centered), solid foreground. Differentiated by both height and
    /// tint, so weekly stays visible even when five-hour ≥ weekly.
    private func combinedBar(provider: MenuBarQuotaBars, tint: Color) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: MenuBarBarMetrics.combinedTrackCornerRadius)
                .fill(tint.opacity(MenuBarBarMetrics.trackOpacity))
                .frame(width: MenuBarBarMetrics.trackWidth, height: MenuBarBarMetrics.combinedTrackHeight)
            RoundedRectangle(cornerRadius: MenuBarBarMetrics.combinedTrackCornerRadius)
                .fill(tint.opacity(MenuBarBarMetrics.weeklyOpacity))
                .frame(width: MenuBarBarMetrics.fillWidth(provider.weekly.normalizedRemaining),
                       height: MenuBarBarMetrics.combinedTrackHeight)
            RoundedRectangle(cornerRadius: MenuBarBarMetrics.combinedInsetCornerRadius)
                .fill(tint)
                .frame(width: MenuBarBarMetrics.fillWidth(provider.fiveHour.normalizedRemaining),
                       height: MenuBarBarMetrics.combinedInsetHeight)
        }
        .frame(width: MenuBarBarMetrics.trackWidth, height: MenuBarBarMetrics.combinedTrackHeight, alignment: .leading)
    }

    private func rowOpacity(_ provider: MenuBarQuotaBars) -> Double {
        switch provider.freshness {
        case .cached, .passive: MenuBarBarMetrics.staleOpacity
        case .confirmed, nil: 1
        }
    }
}
