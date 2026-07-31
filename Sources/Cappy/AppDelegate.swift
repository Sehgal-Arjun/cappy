import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let caffeinator = Caffeinator()
    private let settings = Settings()
    private let loginItem = LoginItem()
    private let notifier = Notifier()

    private var frameTimer: Timer?
    private var screensAsleep = false
    private var shownFrame: CatAnimation.Frame?
    private var shownTitle: String?
    private var menuBarImages: [CatAnimation.Pose: [NSImage]] = [:]
    /// The app that had focus before the dropdown opened, to hand it back after.
    private var previousApp: NSRunningApplication?

    /// The art is 24px tall; the menu bar is 22pt.
    private var iconHeight: CGFloat { min(24, NSStatusBar.system.thickness) }

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
            let images = CatAnimation.strip(for: pose).frames.map { $0.pixelImage(pointHeight: iconHeight) }
            if !images.isEmpty { menuBarImages[pose] = images }
        }

        let hosting = NSHostingController(rootView: MenuView(
            caffeinator: caffeinator,
            settings: settings,
            loginItem: loginItem,
            start: { [weak self] in self?.startSession() },
            quit: { NSApp.terminate(nil) }
        ))

        caffeinator.onSessionEnded = { [weak self] reason in
            guard let self, reason == .timeUp, self.settings.notifyWhenDone else { return }
            self.notifier.postTimeUp()
        }
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        // Redraw straight away when a session starts or ends, not on the next tick.
        caffeinator.$isAwake
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &observers)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

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

    private var observers: Set<AnyCancellable> = []

    func applicationWillTerminate(_ notification: Notification) {
        caffeinator.stop()
    }

    private func startSession() {
        let length = settings.sessionLength()
        // Only timed sessions can run out, so that's when to ask about notifications.
        if length != nil, settings.notifyWhenDone {
            notifier.requestPermission()
        }
        caffeinator.start(for: length)
    }

    // MARK: - Dropdown

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let front = NSWorkspace.shared.frontmostApplication
            previousApp = front == NSRunningApplication.current ? nil : front
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Give focus back to whatever the user was typing in.
        previousApp?.activate()
        previousApp = nil
    }

    // MARK: - Menu bar icon

    @objc private func screensDidSleep() {
        screensAsleep = true
        frameTimer?.invalidate()
    }

    @objc private func screensDidWake() {
        screensAsleep = false
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        let awake = caffeinator.isAwake
        let now = Date.timeIntervalSinceReferenceDate

        let frame = CatAnimation.frame(awake: awake, at: now)
        if frame != shownFrame {
            if let images = menuBarImages[frame.pose], images.indices.contains(frame.index) {
                button.image = images[frame.index]
            } else if button.image == nil {
                // Sprites missing: never leave an invisible, unclickable item.
                button.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Cappy")
            }
            shownFrame = frame
        }

        let title = awake ? (caffeinator.remaining.map(TimeFormat.short) ?? "∞") : ""
        if title != shownTitle {
            button.title = title
            shownTitle = title
        }

        scheduleNextRefresh(after: now, awake: awake)
    }

    /// Wakes up only when the cat's frame or the countdown text can change.
    private func scheduleNextRefresh(after now: TimeInterval, awake: Bool) {
        frameTimer?.invalidate()
        guard !screensAsleep else { return }

        var delay: TimeInterval = 1
        if let frameDelay = CatAnimation.timeUntilNextFrame(awake: awake, at: now) {
            delay = min(delay, frameDelay)
        }
        let timer = Timer(timeInterval: max(0.03, delay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatusItem() }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }
}
