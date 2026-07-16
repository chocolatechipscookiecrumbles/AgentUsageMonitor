import SwiftUI

struct SettingsQuotaPreviewRow: View {
    let title: String
    let window: QuotaWindow
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(window.usedPercent)% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: Double(window.usedPercent), total: 100)
                .tint(tint)

            HStack(alignment: .firstTextBaseline) {
                Text("\(window.remainingPercent)% remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                if let resetAt = window.resetAt {
                    Text(resetAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
