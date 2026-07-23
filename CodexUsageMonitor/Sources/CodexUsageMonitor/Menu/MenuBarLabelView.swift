import SwiftUI

struct MenuBarLabelView: View {
    let presentation: MenuBarLabelPresentation

    var body: some View {
        HStack(spacing: 4) {
            if let providerAssetName = presentation.providerAssetName {
                Image(providerAssetName, bundle: .main)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 13, height: 13)
            }
            if presentation.showsGauge {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
            Text(presentation.text)
                .monospacedDigit()
            if presentation.showsPauseMarker {
                Image(systemName: "pause.fill")
                    .imageScale(.small)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
