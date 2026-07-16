import SwiftUI

struct StatusSettingsContextView: View {
    let title: String
    let summary: String
    let systemImage: String
    let color: Color
    let values: [SettingsContextValue]

    var body: some View {
        SettingsContextCard(title) {
            Label {
                Text(summary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }

            if !values.isEmpty {
                Divider()
                ForEach(values) { value in
                    SettingsContextValueRow(value: value)
                }
            }
        }
    }
}
