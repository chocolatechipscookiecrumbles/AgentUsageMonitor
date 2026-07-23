import SwiftUI

struct UsageProgressBar: View {
    let usedPercent: Int?
    let accessibilityLabel: String

    @Environment(\.colorScheme) private var colorScheme

    init(usedPercent: Int?, accessibilityLabel: String = "Usage") {
        self.usedPercent = usedPercent
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.progressTrack)

                Capsule()
                    .fill(theme.quotaTint(forRemainingPercent: remainingPercent))
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: MenuPopoverTheme.progressBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }

    private var clampedUsedPercent: Int? {
        usedPercent.map { min(max($0, 0), 100) }
    }

    private var remainingPercent: Int? {
        clampedUsedPercent.map { 100 - $0 }
    }

    private var progress: CGFloat {
        CGFloat(clampedUsedPercent ?? 0) / 100
    }

    private var accessibilityValue: String {
        guard let clampedUsedPercent, let remainingPercent else {
            return "Unavailable"
        }
        return "\(clampedUsedPercent) percent used, \(remainingPercent) percent remaining"
    }
}
