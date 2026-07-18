import SwiftUI

struct SettingsPreferenceToggle: View {
    let title: String
    let description: String?
    let descriptionColor: Color?
    @Binding var isOn: Bool

    init(
        _ title: String,
        description: String? = nil,
        descriptionColor: Color? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self.descriptionColor = descriptionColor
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayoutMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                Text(title)
                if let description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(descriptionColor ?? .secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: SettingsLayoutMetrics.rowSpacing)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
