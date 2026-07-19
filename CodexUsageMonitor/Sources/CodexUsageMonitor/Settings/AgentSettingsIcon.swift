import SwiftUI

struct AgentSettingsIcon: View {
    let provider: AgentProvider
    let slotSize: CGFloat
    let artworkMaxSize: CGFloat

    var body: some View {
        Image(provider.settingsAssetName, bundle: .main)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: artworkMaxSize, maxHeight: artworkMaxSize)
        .frame(width: slotSize, height: slotSize)
        .accessibilityHidden(true)
    }
}
