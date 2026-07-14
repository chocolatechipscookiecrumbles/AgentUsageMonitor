import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool { status == .enabled }
    var canChange: Bool { status != .notFound }
    var showsSystemSettingsButton: Bool { status == .requiresApproval || errorMessage != nil }

    var guidanceMessage: String? {
        if let errorMessage { return errorMessage }
        return switch status {
        case .requiresApproval:
            "Approval is required in System Settings."
        case .notFound:
            "Launch at Login is available from the signed app."
        case .notRegistered, .enabled:
            nil
        @unknown default:
            "Launch at Login status is unavailable."
        }
    }

    func refresh() {
        let currentStatus = service.status
        if currentStatus != status {
            errorMessage = nil
        }
        status = currentStatus
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                switch service.status {
                case .enabled:
                    break
                case .requiresApproval:
                    SMAppService.openSystemSettingsLoginItems()
                case .notRegistered, .notFound:
                    try service.register()
                @unknown default:
                    try service.register()
                }
            } else if service.status != .notRegistered && service.status != .notFound {
                try service.unregister()
            }
        } catch {
            errorMessage = "Launch at Login couldn’t be updated. Check Login Items in System Settings."
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
