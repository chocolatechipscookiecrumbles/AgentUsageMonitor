import SwiftUI

struct SettingsContextValueRow: View {
    let value: SettingsContextValue

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(value.value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
