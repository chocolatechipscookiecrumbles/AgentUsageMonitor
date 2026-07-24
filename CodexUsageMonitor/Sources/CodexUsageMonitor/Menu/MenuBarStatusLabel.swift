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
            // The text mode ("5-hour and weekly") shows both windows for Codex
            // via the single-provider presentation; the multi-provider glyph +
            // single percentage was for the removed gauge mode.
            MenuBarLabelView(
                presentation: MenuBarLabelPresentation(
                    displayState: viewModel.displayState,
                    style: settings.menuBarDisplayStyle,
                    valueMode: settings.quotaValueMode
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
