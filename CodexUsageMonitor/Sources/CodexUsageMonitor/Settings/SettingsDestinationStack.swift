import SwiftUI

/// Keeps every Settings destination mounted and switches only which one is
/// visible.
///
/// Selecting a destination through a `switch` removed the previous page, with
/// its own scroll host and AppKit-backed controls, and inserted the next one in
/// the same transaction. During that swap the window could composite
/// duplicated and displaced text for a frame or two. Here every page keeps its
/// identity, scroll host and scroll position for the life of the window; a
/// switch changes opacity, hit testing, accessibility and focus eligibility.
///
/// Pages are ordinary Settings forms with no timers or background work, so
/// keeping six mounted is negligible. Work a page used to do in `onAppear` must
/// also run when it becomes visible (see `SettingsDetailView`).
struct SettingsDestinationStack<Page: View>: View {
    let selection: SettingsTab
    @ViewBuilder let page: (SettingsTab) -> Page

    var body: some View {
        ZStack {
            ForEach(SettingsTab.allCases) { tab in
                let isVisible = tab == selection
                page(tab)
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(isVisible)
                    .accessibilityHidden(!isVisible)
                    // Keeps hidden pages out of keyboard focus traversal.
                    .disabled(!isVisible)
            }
        }
    }
}
