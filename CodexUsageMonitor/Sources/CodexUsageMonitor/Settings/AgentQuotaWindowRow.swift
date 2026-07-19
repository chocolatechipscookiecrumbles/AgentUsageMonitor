import SwiftUI

/// Provider-neutral quota-window presentation for a provider Settings page.
/// An unavailable window remains visible so the page structure does not imply
/// that a provider lacks a session window simply because it is currently idle.
struct AgentQuotaWindowRow: View {
    let title: String
    let window: QuotaWindow?
    let provider: AgentProvider
    let valueMode: QuotaValueMode
    let unavailableText: String

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(valueMode.value(for: window))% \(valueMode.accessibilityName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ProviderQuotaProgressBar(value: valueMode.value(for: window), provider: provider)

                if let resetAt = window.resetAt {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Resets")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(resetAt, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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

                ProviderQuotaProgressBar(value: 0, provider: provider)

                Text("No active session window")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

}
