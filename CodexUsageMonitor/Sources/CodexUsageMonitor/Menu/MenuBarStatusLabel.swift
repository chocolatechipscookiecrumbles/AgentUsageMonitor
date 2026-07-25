import AppKit
import SwiftUI

struct MenuBarStatusLabel: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var settings: AppSettings

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        settings = viewModel.settings
    }

    var body: some View {
        if settings.menuBarDisplayStyle.isGraphical {
            barsLabel
        } else {
            // The text mode ("5-hour and weekly") shows the effective provider's
            // two windows. When more than one provider is connected the user
            // picks which via the General-settings selector, and a provider
            // glyph is shown to disambiguate.
            let eligible = viewModel.menuBarEligibleProviders
            MenuBarLabelView(
                presentation: MenuBarLabelPresentation(
                    provider: viewModel.effectiveMenuBarProvider,
                    codexDisplayState: viewModel.displayState,
                    claudeState: viewModel.claudeState,
                    style: settings.menuBarDisplayStyle,
                    valueMode: settings.quotaValueMode,
                    showsProviderMarker: MenuBarProviderSelection.showsSelector(eligible: eligible)
                )
            )
        }
    }

    /// A `MenuBarExtra` label reliably renders only `Text`/`Image`, not arbitrary
    /// shape-based views, so the bar modes are rasterized into an image. Falls
    /// back to the live view if rendering fails.
    @ViewBuilder
    private var barsLabel: some View {
        let providers = MenuBarQuotaBars.providers(
            codexDisplayState: viewModel.displayState,
            claudeState: viewModel.claudeState
        )
        let view = MenuBarBarsView(style: settings.menuBarDisplayStyle, providers: providers)
        let label = providers.map(\.accessibilityDescription).joined(separator: ". ")

        if let image = Self.rendered(view) {
            Image(nsImage: image)
                .accessibilityLabel(label)
        } else {
            view.accessibilityLabel(label)
        }
    }

    @MainActor
    private static func rendered(_ view: MenuBarBarsView) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        // Keep the provider colors; do not let the menu bar tint it as a template.
        image.isTemplate = false
        return image
    }
}
