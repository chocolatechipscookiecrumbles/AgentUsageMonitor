import SwiftUI

/// The complete visual token set for the menu-bar popover.
///
/// Provider colors remain owned by `AgentProvider`; the popover only derives
/// low-emphasis surfaces from those shared tints.
struct MenuPopoverTheme {
    static let popoverWidth: CGFloat = 340
    static let shellCornerRadius: CGFloat = 14
    static let shellBorderWidth: CGFloat = 1
    static let shellOutlineWidth: CGFloat = 0.5
    static let shellShadowRadius: CGFloat = 48
    static let shellShadowY: CGFloat = 16
    static let cardCornerRadius: CGFloat = 10
    static let cardShadowRadius: CGFloat = 3
    static let cardShadowY: CGFloat = 1
    static let progressBarHeight: CGFloat = 4
    static let statusDotSize: CGFloat = 6
    static let statusPillSpacing: CGFloat = 6
    static let statusPillHorizontalPadding: CGFloat = 8
    static let statusPillVerticalPadding: CGFloat = 3
    static let providerIconTileSize: CGFloat = 28
    static let providerIconTileCornerRadius: CGFloat = 8
    static let providerIconArtworkSize: CGFloat = 18
    static let tabStripHeight: CGFloat = 44
    static let tabIndicatorHeight: CGFloat = 1.5
    static let dividerHeight: CGFloat = 1
    static let headerHorizontalPadding: CGFloat = 16
    static let headerVerticalPadding: CGFloat = 14
    static let headerSpacing: CGFloat = 10
    static let headerTextSpacing: CGFloat = 2
    static let contentHorizontalPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 12
    static let contentPlaceholderHeight: CGFloat = 72
    static let contentSpacing: CGFloat = 12
    static let cardHorizontalPadding: CGFloat = 16
    static let cardVerticalPadding: CGFloat = 14
    static let windowRowSpacing: CGFloat = 8
    static let windowRowFooterSpacing: CGFloat = 4
    static let windowRowDividerInset: CGFloat = 16
    static let forecastTopSpacing: CGFloat = 6
    static let warningStripSpacing: CGFloat = 8
    static let warningStripHorizontalPadding: CGFloat = 12
    static let warningStripVerticalPadding: CGFloat = 9
    static let warningStripIconSize: CGFloat = 12
    static let creditHeaderSpacing: CGFloat = 8
    static let creditIconSize: CGFloat = 14
    static let creditValueSpacing: CGFloat = 8
    static let creditExpirySpacing: CGFloat = 5
    static let compactControlSpacing: CGFloat = 10
    static let compactControlTextSpacing: CGFloat = 3
    static let compactButtonHorizontalPadding: CGFloat = 10
    static let compactButtonVerticalPadding: CGFloat = 6
    static let unavailableIconSize: CGFloat = 40
    static let unavailableSymbolSize: CGFloat = 16
    static let unavailableTextWidth: CGFloat = 220
    static let footerVerticalPadding: CGFloat = 10
    static let actionRowHeight: CGFloat = 34
    static let actionRowHorizontalPadding: CGFloat = 16
    static let actionRowIconSize: CGFloat = 13
    static let actionRowIconWidth: CGFloat = 16
    static let actionRowSpacing: CGFloat = 10

    let windowBackground: Color
    let tabStripBackground: Color
    let cardBackground: Color
    let border: Color
    let divider: Color
    let progressTrack: Color
    let primaryText: Color
    let secondaryText: Color
    let icon: Color
    let hoverBackground: Color
    let shellShadow: Color
    let shellOutline: Color
    let cardShadow: Color
    let accent: Color
    let success: Color
    let warning: Color
    let danger: Color
    let neutral: Color

    static func resolve(for colorScheme: ColorScheme) -> Self {
        let accent = rgb(10, 132, 255)
        let success = rgb(48, 209, 88)
        let warning = rgb(255, 159, 10)
        let danger = rgb(255, 69, 58)
        let neutral = rgb(142, 142, 147)

        if colorScheme == .dark {
            return Self(
                windowBackground: rgb(36, 36, 36),
                tabStripBackground: rgb(30, 30, 30),
                cardBackground: .white.opacity(0.055),
                border: .white.opacity(0.07),
                divider: .white.opacity(0.06),
                progressTrack: .white.opacity(0.09),
                primaryText: .white,
                secondaryText: .white.opacity(0.40),
                icon: .white.opacity(0.35),
                hoverBackground: .white.opacity(0.05),
                shellShadow: .black.opacity(0.55),
                shellOutline: .white.opacity(0.07),
                cardShadow: .clear,
                accent: accent,
                success: success,
                warning: warning,
                danger: danger,
                neutral: neutral
            )
        }

        return Self(
            windowBackground: rgb(245, 245, 247),
            tabStripBackground: rgb(235, 235, 235),
            cardBackground: .white,
            border: .black.opacity(0.07),
            divider: .black.opacity(0.06),
            progressTrack: .black.opacity(0.07),
            primaryText: rgb(28, 28, 30),
            secondaryText: .black.opacity(0.38),
            icon: .black.opacity(0.30),
            hoverBackground: .black.opacity(0.03),
            shellShadow: .black.opacity(0.14),
            shellOutline: .black.opacity(0.08),
            cardShadow: .black.opacity(0.06),
            accent: accent,
            success: success,
            warning: warning,
            danger: danger,
            neutral: neutral
        )
    }

    /// One usage-severity scale for every popover bar and numeral, expressed in
    /// *used* terms: `used < 75` → success, `75…90` → warning, `> 90` → danger.
    /// The color always tracks usage, never the displayed value, so it is
    /// correct whether a surface shows "% used" or "% remaining". Callers pass
    /// remaining (`100 − used`), so the equivalent boundaries are
    /// `remaining < 10` → danger and `remaining ≤ 25` → warning.
    static func quotaLevel(forRemainingPercent remainingPercent: Int?) -> MenuPopoverQuotaLevel {
        guard let remainingPercent else { return .unavailable }
        if remainingPercent < 10 { return .danger }
        if remainingPercent <= 25 { return .warning }
        return .success
    }

    func quotaTint(forRemainingPercent remainingPercent: Int?) -> Color {
        switch Self.quotaLevel(forRemainingPercent: remainingPercent) {
        case .success: success
        case .warning: warning
        case .danger: danger
        case .unavailable: neutral
        }
    }

    func statusTint(_ status: MenuPopoverStatus) -> Color {
        switch status {
        case .confirmed: success
        case .cached: warning
        case .refreshing: accent
        case .unavailable: neutral
        }
    }

    func statusBackground(_ status: MenuPopoverStatus) -> Color {
        statusTint(status).opacity(0.12)
    }

    func providerTileBackground(_ provider: AgentProvider) -> Color {
        provider.settingsPresentationTint.opacity(0.12)
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
