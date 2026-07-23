import AppKit
import SwiftUI

struct WindowPopoverGateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Window Popover Gate")
                    .font(.headline)
                Text("Check dismissal, keyboard focus, and menu bar toggling before the Figma port.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button("Open Settings…", action: openSettingsAndDismiss)
                Button("Close Popover", action: dismissPopover)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func openSettingsAndDismiss() {
        dismissPopover()
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func dismissPopover() {
        dismiss()
    }
}
