import ServiceManagement

/// "Open at login", via the system's login items.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false
    /// Set when macOS wants the user to approve it in System Settings.
    @Published private(set) var needsApproval = false
    @Published private(set) var errorMessage: String?

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Couldn't change that. Try moving Cappy to Applications first."
            NSLog("Cappy: login item change failed: \(error)")
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
