import Combine
import SwiftUI

/// The only object the panel's SwiftUI tree observes. The content pipeline
/// publishes into it after the window has grown to hold the new state, so no
/// content reaches the screen before it has been measured (ADR 0004).
@MainActor
final class MenuPanelModel: ObservableObject {
    @Published private(set) var state: MenuPanelState
    @Published private(set) var maximumHeight: CGFloat

    init(state: MenuPanelState, maximumHeight: CGFloat) {
        self.state = state
        self.maximumHeight = maximumHeight
    }

    func publish(_ next: MenuPanelState) {
        state = next
    }

    func updateMaximumHeight(_ height: CGFloat) {
        if height != maximumHeight { maximumHeight = height }
    }
}

/// The panel's hosted root: the menu shell, anchored to the top of the window
/// so a window taller than the shell never moves the tabs or header (ADR 0004 I1).
struct MenuPanelRoot: View {
    @ObservedObject var model: MenuPanelModel
    let actions: MenuSurfaceActions
    let onSettledHeight: (CGFloat) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MenuSurface(
            state: model.state,
            maximumHeight: model.maximumHeight,
            actions: actions,
            onSettledHeight: onSettledHeight
        )
        .background(theme.windowBackground)
        .clipShape(.rect(cornerRadius: MenuPopoverTheme.shellCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
                .stroke(theme.border, lineWidth: MenuPopoverTheme.shellBorderWidth)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MenuPopoverTheme.shellCornerRadius)
                .stroke(theme.shellOutline, lineWidth: MenuPopoverTheme.shellOutlineWidth)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}
