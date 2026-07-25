import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let caffeinator = Caffeinator()
    private let settings = Settings()

    private var animationTimer: Timer?
    private var shownFrame: CatAnimation.Frame?
    private var shownTitle = ""
    private var menuBarImages: [CatAnimation.Pose: [NSImage]] = [:]

    private static let iconHeight: CGFloat = 20

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.setAccessibilityLabel("Cappy")
        }

        for pose in [CatAnimation.Pose.idle, .groom, .sleep] {
            menuBarImages[pose] = CatAnimation.strip(for: pose).frames.map {
                $0.pixelImage(pointHeight: Self.iconHeight)
            }
        }

        let hosting = NSHostingController(rootView: MenuView(
            caffeinator: caffeinator,
            settings: settings,
            quit: { NSApp.terminate(nil) }
        ))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        let timer = Timer(timeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatusItem() }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
        refreshStatusItem()

        // Dev hook: `Cappy --keep-awake 30` starts a 30 second session on launch.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--keep-awake"), i + 1 < args.count, let seconds = Double(args[i + 1]) {
            caffeinator.start(for: seconds)
        }
        // Dev hook: `Cappy --show-menu` opens the dropdown on launch.
        if args.contains("--show-menu"), let button = statusItem.button {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover(button) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinator.stop()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        let awake = caffeinator.isAwake

        let frame = CatAnimation.frame(awake: awake, at: Date.timeIntervalSinceReferenceDate)
        if frame != shownFrame,
           let images = menuBarImages[frame.pose], images.indices.contains(frame.index) {
            button.image = images[frame.index]
            shownFrame = frame
        }

        var title = ""
        if awake {
            title = caffeinator.remaining.map(TimeFormat.short) ?? "∞"
        }
        if title != shownTitle {
            button.title = title
            shownTitle = title
        }
    }
}
