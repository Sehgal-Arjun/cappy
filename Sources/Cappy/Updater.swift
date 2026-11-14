import AppKit
import Sparkle

/// Auto-updates via Sparkle. The feed URL and public key live in Info.plist;
/// updates must be signed with the matching private key (see scripts/release.sh).
@MainActor
final class Updater: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// A scheduled check found an update while the user wasn't looking;
    /// the menu shows it instead of a window popping up out of nowhere.
    @Published private(set) var updateAvailable = false

    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    /// The same check a scheduled one does: quiet unless something's found.
    func checkInBackground() {
        controller.updater.checkForUpdatesInBackground()
    }

    // MARK: SPUUpdaterDelegate

    /// Test hook: `CAPPY_FEED_URL=… Cappy` points at another feed.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        ProcessInfo.processInfo.environment["CAPPY_FEED_URL"]
    }

    // MARK: SPUStandardUserDriverDelegate (gentle reminders for a menu bar app)

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Only let Sparkle open its window if the user is already looking at Cappy.
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        Task { @MainActor in
            if handleShowingUpdate {
                NSApp.activate(ignoringOtherApps: true)
            } else {
                self.updateAvailable = true
            }
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in self.updateAvailable = false }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.updateAvailable = false }
    }
}
