import AppKit
import SwiftUI

/// The first-run tour. Pure presentation: it renders the current page and emits
/// intents, and it never persists, connects, or presents a window itself.
struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let contentWidth: CGFloat = 760
    static let contentHeight: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            artwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.top, 40)

            copy
                .padding(.horizontal, 64)
                .padding(.top, 28)
                .padding(.bottom, 24)

            Divider()

            controls
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: Self.contentWidth, height: Self.contentHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        // Arrow keys drive the tour only when no focused control claims them,
        // so Tab-based focus movement keeps working unchanged.
        .onKeyPress(.leftArrow) {
            viewModel.goBack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.goForward()
            return .handled
        }
    }

    /// Artwork is supplied out of band. When the imageset is absent the page
    /// still reads correctly rather than showing a broken-image box or a
    /// placeholder a reviewer could mistake for final art.
    @ViewBuilder
    private var artwork: some View {
        if let image = NSImage(named: viewModel.currentPage.assetName) {
            Image(nsImage: image)
                .resizable()
                // Scales down without cropping: these are composed screens, so
                // filling the region would cut the content they exist to show.
                .scaledToFit()
                .accessibilityLabel(viewModel.currentPage.imageAccessibilityDescription)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(nsColor: .separatorColor))
                }
                .accessibilityHidden(true)
        }
    }

    private var copy: some View {
        VStack(spacing: 10) {
            Text(viewModel.currentPage.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(viewModel.currentPage.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.currentPageIndex)
    }

    /// One row: back, the page indicator, forward, then Dismiss on the trailing
    /// edge. Dismiss keeps the same label on every page because it always does
    /// the same thing — close the tour without connecting anything.
    private var controls: some View {
        HStack(spacing: 12) {
            arrow(
                systemImage: "chevron.left",
                label: "Previous page",
                enabled: viewModel.canGoBack,
                action: viewModel.goBack
            )

            pageIndicator

            arrow(
                systemImage: "chevron.right",
                label: "Next page",
                enabled: viewModel.canGoForward,
                action: viewModel.goForward
            )

            Spacer(minLength: 16)

            Button("Dismiss", action: viewModel.dismiss)
                .keyboardShortcut(.cancelAction)
        }
    }

    private func arrow(
        systemImage: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 24, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// One accessibility element rather than three: VoiceOver should hear the
    /// position, not three unlabeled shapes.
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, _ in
                Circle()
                    .fill(index == viewModel.currentPageIndex ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(viewModel.currentPageIndex + 1) of \(viewModel.pages.count)")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.currentPageIndex)
    }
}
