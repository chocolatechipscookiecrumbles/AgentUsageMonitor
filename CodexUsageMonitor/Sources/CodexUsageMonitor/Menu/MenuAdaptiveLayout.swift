import SwiftUI

/// Content keeps its intrinsic height; the scroll viewport accepts the bounded
/// height. A fixed-size scroll view inside a max-height frame draws outside it.
struct MenuAdaptiveLayout<Header: View, Content: View, Footer: View>: View {
    let selection: AgentProvider
    let maximumHeight: CGFloat
    var sizeChanged: (CGSize) -> Void = { _ in }
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    @State private var heights: [String: CGFloat] = [:]

    private var viewportHeight: CGFloat {
        min(heights["content", default: 0], max(0,
            maximumHeight - heights["header", default: 0] - heights["footer", default: 0]
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) { header }
                .fixedSize(horizontal: false, vertical: true)
                .background(measure("header"))
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .background(measure("content"))
                        .id("menu-content-top")
                }
                .frame(height: viewportHeight)
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: selection) { _, _ in
                    proxy.scrollTo("menu-content-top", anchor: .top)
                }
            }
            footer
                .fixedSize(horizontal: false, vertical: true)
                .background(measure("footer"))
        }
        .frame(width: MenuPopoverTheme.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onPreferenceChange(MenuLayoutHeightsKey.self) { value in
            if heights != value { heights = value }
        }
        .onChange(of: totalHeight) { _, height in
            guard heights.count == 3 else { return }
            sizeChanged(CGSize(width: MenuPopoverTheme.popoverWidth, height: height))
        }
    }

    private var totalHeight: CGFloat {
        heights["header", default: 0] + viewportHeight + heights["footer", default: 0]
    }

    private func measure(_ region: String) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(key: MenuLayoutHeightsKey.self, value: [region: geometry.size.height])
        }
    }
}

private struct MenuLayoutHeightsKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
