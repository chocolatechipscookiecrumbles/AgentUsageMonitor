import SwiftUI

/// Shared page shell for an entry in the in-Settings agent selector.
///
/// `SettingsView` remains the only owner of destination and window navigation;
/// this template standardizes only the page interior that changes by provider.
struct AgentSettingsPageTemplate<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SettingsPage(fillsViewport: true) {
            content
        }
    }
}
