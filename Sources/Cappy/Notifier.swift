import AppKit
import UserNotifications

/// Posts the "time's up" notification and tracks whether macOS allows it.
@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    /// True when the user has turned Cappy's notifications off in System Settings.
    @Published private(set) var isBlocked = false

    /// UNUserNotificationCenter crashes outside an app bundle (e.g. `swift run`).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    override init() {
        super.init()
        center?.delegate = self
        refreshStatus()
    }

    /// Asks once; macOS remembers the answer.
    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    func refreshStatus() {
        center?.getNotificationSettings { [weak self] settings in
            let blocked = settings.authorizationStatus == .denied
            Task { @MainActor in self?.isBlocked = blocked }
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func postTimeUp() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Cappy is napping"
        content.body = "Time's up. Your Mac can sleep as usual again."
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "time-up", content: content, trigger: nil)) { error in
            if let error { NSLog("Cappy: couldn't post notification: \(error)") }
        }
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
