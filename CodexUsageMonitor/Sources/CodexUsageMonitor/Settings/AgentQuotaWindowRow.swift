import SwiftUI

/// Provider-neutral quota-window presentation for a provider Settings page.
/// An unavailable window remains visible so the page structure does not imply
/// that a provider lacks a session window simply because it is currently idle.
struct AgentQuotaWindowRow: View {
    let title: String
    let window: QuotaWindow?
    let provider: AgentProvider
    let unavailableText: String

    var body: some View {
        if let window {
            SettingsQuotaPreviewRow(
                title: title,
                window: window,
                tint: provider.settingsPresentationTint
            )
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(unavailableText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: 0, total: 100)
                    .tint(provider.settingsPresentationTint)

                Text("No active session window")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
