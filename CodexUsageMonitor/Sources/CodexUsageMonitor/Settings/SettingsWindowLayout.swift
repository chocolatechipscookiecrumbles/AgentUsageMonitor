import CoreGraphics

struct SettingsWindowLayout: Equatable {
    let contentSize: CGSize
    let sidebarWidth: CGFloat
    let settingsPageWidth: CGFloat

    init(isContextRailVisible: Bool) {
        sidebarWidth = SettingsLayoutMetrics.sidebarWidth
        settingsPageWidth = SettingsLayoutMetrics.settingsPageWidth
        let railAllocation = isContextRailVisible
            ? SettingsLayoutMetrics.contextRailWidth + SettingsLayoutMetrics.dividerWidth
            : 0
        contentSize = CGSize(
            width: SettingsLayoutMetrics.hiddenWindowWidth + railAllocation,
            height: SettingsLayoutMetrics.targetWindowHeight
        )
    }
}
