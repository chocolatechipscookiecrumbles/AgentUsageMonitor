import SwiftUI

enum SettingsLayoutMetrics {
    static let hiddenWindowWidth: CGFloat = 680
    static let targetWindowHeight: CGFloat = 560
    static let sidebarWidth: CGFloat = 180
    static let contextRailWidth: CGFloat = 210
    static let dividerWidth: CGFloat = 1
    static let settingsPageWidth = hiddenWindowWidth - sidebarWidth - dividerWidth

    static let pageHeaderHeight: CGFloat = 52
    static let compactWidthBreakpoint: CGFloat = 500
    static let labelWidth: CGFloat = 148
    static let controlWidth: CGFloat = 190
    static let appearanceSegmentedControlWidth: CGFloat = 240
    static let sectionCornerRadius: CGFloat = 10
    static let sectionContentPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let compactRowSpacing: CGFloat = 4
    static let regularPageHorizontalPadding: CGFloat = 20
    static let compactPageHorizontalPadding: CGFloat = 16
    static let regularPageVerticalPadding: CGFloat = 16
    static let compactPageVerticalPadding: CGFloat = 16
    static let regularSectionSpacing: CGFloat = 20
    static let compactSectionSpacing: CGFloat = 20

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

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = SettingsLayoutMode(width: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: SettingsLayoutMetrics.sectionSpacing(for: layout)) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SettingsLayoutMetrics.pageHorizontalPadding(for: layout))
                .padding(.vertical, SettingsLayoutMetrics.pageVerticalPadding(for: layout))
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.settingsLayoutMode, layout)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    private let content: Content

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

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SettingsLayoutMetrics.sectionContentPadding)
            .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsLayoutMetrics.sectionCornerRadius)
                    .stroke(.quaternary, lineWidth: 0.5)
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
