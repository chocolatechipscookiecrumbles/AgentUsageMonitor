import Foundation
import OSLog

enum ProviderSwitchSurface: String {
    case settingsAgents
    case menuPopover
}

enum ProviderSwitchPhase: String {
    case buttonAction
    case selectionChanged
    case contentAppeared
    case windowResized
}

enum ProviderSwitchTrace {
    static let launchArgument = "--provider-switch-diagnostic"
    static let logger = Logger(
        subsystem: "CodexUsageMonitor",
        category: "ProviderSwitchDiagnostic"
    )

    static var isEnabled: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    @MainActor
    static func record(
        surface: ProviderSwitchSurface,
        phase: ProviderSwitchPhase,
        provider: AgentProvider,
        detail: String = ""
    ) {
        guard isEnabled else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        logger.notice(
            "[DEBUG-provider-switch] uptime=\(uptime, format: .fixed(precision: 6), privacy: .public) surface=\(surface.rawValue, privacy: .public) phase=\(phase.rawValue, privacy: .public) provider=\(provider.rawValue, privacy: .public) detail=\(detail, privacy: .public)"
        )
    }
}
