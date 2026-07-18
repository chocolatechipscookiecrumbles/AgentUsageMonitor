import SwiftUI

struct SettingsPreferenceControlRow<Control: View>: View {
    let title: String
    let description: String?
    private let control: Control

    init(
        _ title: String,
        description: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayoutMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: SettingsLayoutMetrics.preferenceTitleDescriptionSpacing) {
                Text(title)
                if let description {
                    SettingsDescription(description)
                }
            }
            .frame(minWidth: SettingsLayoutMetrics.preferenceControlMinimumTextWidth, alignment: .leading)

            Spacer(minLength: SettingsLayoutMetrics.rowSpacing)

            control
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsUnavailablePreferenceControlRow: View {
    let title: String
    let description: String
    let isOn: Bool
    let availability: String

    init(_ title: String, description: String, isOn: Bool, availability: String) {
        self.title = title
        self.description = description
        self.isOn = isOn
        self.availability = availability
    }

    var body: some View {
        SettingsPreferenceControlRow(title, description: description) {
            VStack(alignment: .trailing, spacing: SettingsLayoutMetrics.unavailableControlStatusSpacing) {
                Toggle(title, isOn: .constant(isOn))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(true)

                Text(availability)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(availability)
            .accessibilityHint("This control does not change refresh scheduling yet.")
        }
    }
}
