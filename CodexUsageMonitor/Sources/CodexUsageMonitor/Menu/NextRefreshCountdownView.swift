import SwiftUI

struct NextRefreshCountdownView: View {
    @ObservedObject var clock: RefreshCountdownClock

    var body: some View {
        Text(clock.text)
            .font(.caption)
            .accessibilityLabel(clock.text)
    }
}
