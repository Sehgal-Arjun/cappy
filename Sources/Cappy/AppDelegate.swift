import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let caffeinator = Caffeinator()
    private var tick: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Temporary plain menu until the real dropdown lands.
        let menu = NSMenu()
        menu.addItem(withTitle: "Keep awake for 1 minute", action: #selector(startOneMinute), keyEquivalent: "")
        menu.addItem(withTitle: "Keep awake until stopped", action: #selector(startForever), keyEquivalent: "")
        menu.addItem(withTitle: "Stop", action: #selector(stop), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cappy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu

        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTitle() }
        }
        refreshTitle()

        // Dev hook: `Cappy --keep-awake 30` starts a 30 second session on launch.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--keep-awake"), i + 1 < args.count, let seconds = Double(args[i + 1]) {
            caffeinator.start(for: seconds)
            refreshTitle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinator.stop()
    }

    @objc private func startOneMinute() { caffeinator.start(for: 60); refreshTitle() }
    @objc private func startForever() { caffeinator.start(for: nil); refreshTitle() }
    @objc private func stop() { caffeinator.stop(); refreshTitle() }

    private func refreshTitle() {
        guard caffeinator.isAwake else {
            statusItem.button?.title = "Cappy (asleep)"
            return
        }
        if let remaining = caffeinator.remaining {
            let s = Int(remaining.rounded(.up))
            statusItem.button?.title = String(format: "Cappy %d:%02d", s / 60, s % 60)
        } else {
            statusItem.button?.title = "Cappy ∞"
        }
    }
}
