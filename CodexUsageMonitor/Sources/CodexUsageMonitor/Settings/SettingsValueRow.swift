import SwiftUI

/// A row whose trailing side is *text*, not a control.
///
/// `SettingsPreferenceControlRow` pins its trailing control with
/// `.fixedSize(horizontal: true)` so a native picker or segment keeps its
/// intrinsic width. That is right for controls and wrong for text: a value
/// like "Cached Claude OAuth result · 3 hours ago" exceeds
/// `trailingControlBudget` and pushes the whole card past the page's trailing
/// edge. Here the value is allowed to wrap instead, so a long reading costs a
/// line rather than the layout.
struct SettingsValueRow: View {
    let title: String
    let value: String
    /// Attached beneath the title, in the shared description treatment, for
    /// text that explains this specific row.
    var description: String?

    init(_ title: String, value: String, description: String? = nil) {
        self.title = title
        self.value = value
        self.description = description
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

            Text(value)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
