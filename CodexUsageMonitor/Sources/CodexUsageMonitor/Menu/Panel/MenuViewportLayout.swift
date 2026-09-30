import SwiftUI

/// Header, provider viewport and footer, allocated in one layout pass.
///
/// The viewport's ideal height is its content's height (a vertical scroll view
/// reports content as its ideal size on the scroll axis). It receives the
/// smaller of that and the space left under `maximumHeight`, so tall content
/// scrolls instead of drawing through the header and footer. Unlike
/// `MenuAdaptiveLayout` it keeps no measured `@State`, so an offscreen host
/// produces the same height as the live panel.
struct MenuViewportLayout: Layout {
    var maximumHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? MenuPopoverTheme.popoverWidth
        return CGSize(width: width, height: allocation(subviews, width: width).reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (subview, height) in zip(subviews, allocation(subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
            y += height
        }
    }

    /// Heights for [header, viewport, footer].
    private func allocation(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        precondition(subviews.count == 3, "MenuViewportLayout expects header, viewport, footer")
        let unbounded = ProposedViewSize(width: width, height: nil)
        let header = subviews[0].sizeThatFits(unbounded).height
        let footer = subviews[2].sizeThatFits(unbounded).height
        let content = subviews[1].sizeThatFits(unbounded).height
        return [header, min(content, max(0, maximumHeight - header - footer)), footer]
    }
}
