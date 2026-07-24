import SwiftUI

enum SettingsLayoutMetrics {
    static let hiddenWindowWidth: CGFloat = 680
    static let targetWindowHeight: CGFloat = 560
    static let sidebarWidth: CGFloat = 180
    static let contextRailWidth: CGFloat = 210
    static let dividerWidth: CGFloat = 1
    static let settingsPageWidth = hiddenWindowWidth - sidebarWidth - dividerWidth

    static let pageHeaderHeight: CGFloat = 52
    static let pageHeaderHorizontalPadding: CGFloat = 20
    static let pageHeaderContentSpacing: CGFloat = 12
    static let agentHeaderItemHorizontalPadding: CGFloat = 12
    static let agentHeaderTabWidth: CGFloat = 132
    static let agentHeaderIconSlotSize: CGFloat = 20
    static let agentHeaderIconArtworkMaxSize: CGFloat = 16
    static let agentContextIconSlotSize: CGFloat = 16
    static let agentContextIconArtworkMaxSize: CGFloat = 12
    static let agentQuotaProgressBarHeight: CGFloat = 6
    static let agentHeaderItemSpacing: CGFloat = 6
    static let agentHeaderUnderlineHeight: CGFloat = 2
    static let agentHeaderUnderlineWidth: CGFloat = 96
    static let agentHeaderDividerHeight: CGFloat = 22
    static let agentWarningControlsSpacing: CGFloat = 10
    static let agentWarningChipSpacing: CGFloat = 8
    static let agentWarningChipWidth: CGFloat = 46
    static let agentWarningChipHeight: CGFloat = 28
    static let agentWarningChipHorizontalPadding: CGFloat = 10
    static let agentWarningChipCornerRadius: CGFloat = 8
    static let agentWarningChipCheckmarkSize: CGFloat = 12
    static let agentWarningChipIconSpacing: CGFloat = 4
    static let agentWarningDisabledChipOpacity: CGFloat = 0.55
    static let agentResetCreditsAnnotationSpacing: CGFloat = 8
    static let agentOnboardingContentSpacing: CGFloat = 12
    static let agentOnboardingTextSpacing: CGFloat = 4
    static let agentOnboardingVerticalPadding: CGFloat = 20
    static let agentOnboardingHorizontalPadding: CGFloat = 20
    static let agentOnboardingIconSlotSize: CGFloat = 44
    static let agentOnboardingIconArtworkMaxSize: CGFloat = 22
    static let agentOnboardingIconCornerRadius: CGFloat = 16
    static let agentOnboardingTextMaxWidth: CGFloat = 280
    static let compactWidthBreakpoint: CGFloat = 500
    static let labelWidth: CGFloat = 148
    static let controlWidth: CGFloat = 190
    static let compactSegmentedControlWidth: CGFloat = 220
    static let appearanceSegmentedControlWidth: CGFloat = 220
    static let sectionCornerRadius: CGFloat = 10
    static let sectionContentHorizontalPadding: CGFloat = 14
    static let sectionRowVerticalPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let preferenceTitleDescriptionSpacing: CGFloat = 3
    static let preferenceControlMinimumTextWidth: CGFloat = 168
    static let unavailableControlStatusSpacing: CGFloat = 4
    static let compactRowSpacing: CGFloat = 4
    static let regularPageHorizontalPadding: CGFloat = 20
    static let compactPageHorizontalPadding: CGFloat = 16
    static let regularPageVerticalPadding: CGFloat = 16
    static let compactPageVerticalPadding: CGFloat = 16
    static let regularSectionSpacing: CGFloat = 20
    static let compactSectionSpacing: CGFloat = 20

    /// Width left for a row's trailing control after the page inset, the card
    /// inset, the leading text minimum, and the inter-column spacing.
    ///
    /// A trailing control wider than this widens the row and pushes the card
    /// past the page's trailing edge — the defect recorded in AGENTS.md's
    /// Settings card geometry guardrails. A child `.frame(maxWidth: .infinity)`
    /// does not prevent it, because the overflow is intrinsic-width driven.
    /// Consult this before giving any row a fixed-size trailing control.
    static func trailingControlBudget(pageWidth: CGFloat, layout: SettingsLayoutMode) -> CGFloat {
        let insets = pageHorizontalPadding(for: layout) * 2 + sectionContentHorizontalPadding * 2
        // Two HStack gaps plus the Spacer's minLength, all rowSpacing.
        let spacing = rowSpacing * 3
        return max(0, pageWidth - insets - preferenceControlMinimumTextWidth - spacing)
    }

    static func valueColumnInset(for layout: SettingsLayoutMode) -> CGFloat {
        layout == .compact ? 0 : labelWidth + rowSpacing
    }

    static func pageHorizontalPadding(for layout: SettingsLayoutMode) -> CGFloat {
        layout == .compact ? compactPageHorizontalPadding : regularPageHorizontalPadding
    }

    static func pageVerticalPadding(for layout: SettingsLayoutMode) -> CGFloat {
        layout == .compact ? compactPageVerticalPadding : regularPageVerticalPadding
    }

    static func sectionSpacing(for layout: SettingsLayoutMode) -> CGFloat {
        layout == .compact ? compactSectionSpacing : regularSectionSpacing
    }
}

enum SettingsLayoutMode {
    case compact
    case regular

    init(width: CGFloat) {
        self = width < SettingsLayoutMetrics.compactWidthBreakpoint ? .compact : .regular
    }
}

private struct SettingsLayoutModeKey: EnvironmentKey {
    static let defaultValue = SettingsLayoutMode.regular
}

extension EnvironmentValues {
    fileprivate var settingsLayoutMode: SettingsLayoutMode {
        get { self[SettingsLayoutModeKey.self] }
        set { self[SettingsLayoutModeKey.self] = newValue }
    }
}

struct SettingsPage<Content: View>: View {
    private let content: Content
    private let fillsViewport: Bool
    @Environment(\.settingsAppearancePalette) private var palette

    init(
        fillsViewport: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.fillsViewport = fillsViewport
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = SettingsLayoutMode(width: geometry.size.width)
            let verticalPadding = SettingsLayoutMetrics.pageVerticalPadding(for: layout)

            ScrollView {
                VStack(alignment: .leading, spacing: SettingsLayoutMetrics.sectionSpacing(for: layout)) {
                    content
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: fillsViewport
                        ? max(0, geometry.size.height - verticalPadding * 2)
                        : nil,
                    alignment: .topLeading
                )
                .padding(.horizontal, SettingsLayoutMetrics.pageHorizontalPadding(for: layout))
                .padding(.vertical, verticalPadding)
            }
            .background(palette.pageBackground)
            .environment(\.settingsLayoutMode, layout)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    private let content: Content
    @Environment(\.settingsAppearancePalette) private var palette

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.35)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsLayoutMetrics.sectionContentHorizontalPadding)
            .background(palette.sectionSurface, in: .rect(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius)
                    .stroke(palette.divider, lineWidth: 0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsLabeledRow<Content: View>: View {
    @Environment(\.settingsLayoutMode) private var layout
    let label: String
    private let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        Group {
            if layout == .compact {
                VStack(alignment: .leading, spacing: SettingsLayoutMetrics.compactRowSpacing) {
                    Text(label)
                        .foregroundStyle(.secondary)

                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: SettingsLayoutMetrics.rowSpacing) {
                    Text(label)
                        .frame(width: SettingsLayoutMetrics.labelWidth, alignment: .leading)

                    content
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsValueColumnAlignment: ViewModifier {
    @Environment(\.settingsLayoutMode) private var layout

    func body(content: Content) -> some View {
        content.padding(.leading, SettingsLayoutMetrics.valueColumnInset(for: layout))
    }
}

extension View {
    func settingsValueColumnAligned() -> some View {
        modifier(SettingsValueColumnAlignment())
    }
}

struct SettingsDescription: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
