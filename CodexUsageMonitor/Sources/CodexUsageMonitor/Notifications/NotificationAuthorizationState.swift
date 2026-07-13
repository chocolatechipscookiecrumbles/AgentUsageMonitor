import Foundation

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case unavailable

    var statusMessage: String? {
        switch self {
        case .unknown:
            nil
        case .notDetermined:
            "macOS will ask for permission when notifications are enabled."
        case .denied:
            "Notifications are disabled for this app in System Settings."
        case .authorized:
            "macOS notification permission is granted."
        case .unavailable:
            "Notification permission is available only from the built app bundle."
        }
    }
}
