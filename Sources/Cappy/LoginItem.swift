import Foundation
import ServiceManagement

/// "Open at login", via the system's login items.
@MainActor
final class LoginItem: ObservableObject {
    /// On, including "registered but waiting for approval", so it can be switched off.
    @Published private(set) var isEnabled = false
    /// Set when macOS wants the user to approve it in System Settings.
    @Published private(set) var needsApproval = false
    @Published private(set) var errorMessage: String?

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }

    /// Registering from the DMG or a quarantined copy records a path that's
    /// gone by the next login, so only allow it from Applications.
    private var isInstalled: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") && !path.contains("/AppTranslocation/")
    }

    func set(_ enabled: Bool) {
        errorMessage = nil
        if enabled && !isInstalled {
            errorMessage = "Move Cappy to your Applications folder first, then turn this on."
            refresh()
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Couldn't change that. Try again from System Settings › General › Login Items."
            NSLog("Cappy: login item change failed: \(error)")
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
