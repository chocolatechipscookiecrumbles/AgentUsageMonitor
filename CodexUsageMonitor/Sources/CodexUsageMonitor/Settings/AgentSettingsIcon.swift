import SwiftUI

struct AgentSettingsIcon: View {
    let provider: AgentProvider
    let slotSize: CGFloat
    let artworkMaxSize: CGFloat

    var body: some View {
        Group {
            if let image = AgentSettingsIconResource.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: artworkMaxSize, maxHeight: artworkMaxSize)
            }
        }
        .frame(width: slotSize, height: slotSize)
        .accessibilityHidden(true)
    }
}
