import SwiftUI

/// Provider-neutral reset-credit summary and expiry annotations.
struct AgentResetCreditsRow: View {
    let provider: AgentProvider
    let availableCount: Int?
    let expiries: [Date]

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsLayoutMetrics.agentResetCreditsAnnotationSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("Earned Reset Credits")
                    .fontWeight(.semibold)

                Spacer(minLength: SettingsLayoutMetrics.rowSpacing)

                if let availableCount {
                    Text("\(availableCount.formatted()) Available")
                        .foregroundStyle(provider.settingsPresentationTint)
                        .monospacedDigit()
                } else {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                }
            }

            if expiries.isEmpty {
                SettingsDescription("No reset credit expirations available.")
            } else {
                ForEach(expiries, id: \.self) { expiry in
                    Label {
                        Text(expiry, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
