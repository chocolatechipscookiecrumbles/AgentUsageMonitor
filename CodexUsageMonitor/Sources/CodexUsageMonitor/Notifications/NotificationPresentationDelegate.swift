import UserNotifications

/// Presents notifications as banners even when the app is frontmost.
///
/// Without a delegate, macOS routes a notification delivered while its own app
/// is active straight to Notification Center with no banner. This opts every
/// notification — quota alerts and quota-setting confirmations alike — into a
/// banner, list entry, and sound regardless of focus.
final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationPresentationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
