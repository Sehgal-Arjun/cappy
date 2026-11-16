import Foundation
import UserNotifications

/// Posts the "time's up" notification.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    /// UNUserNotificationCenter crashes outside an app bundle (e.g. `swift run`).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    override init() {
        super.init()
        center?.delegate = self
    }

    /// Asks once; macOS remembers the answer.
    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTimeUp() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Cappy is napping"
        content.body = "Time's up. Your Mac can sleep as usual again."
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "time-up", content: content, trigger: nil))
    }

    // Show the banner even though Cappy counts as the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
