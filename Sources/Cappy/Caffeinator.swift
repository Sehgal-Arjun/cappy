import Foundation

/// Which `caffeinate` assertions to hold while awake.
struct KeepAwakeFlags: Codable, Equatable {
    var display = true   // -d
    var idle = true      // -i
    var disk = true      // -m
    var system = true    // -s (only honoured on AC power)
    var user = true      // -u

    /// e.g. "-dimsu", or nil when nothing is selected
    /// (caffeinate then falls back to preventing idle sleep).
    var argument: String? {
        var letters = ""
        if display { letters += "d" }
        if idle { letters += "i" }
        if disk { letters += "m" }
        if system { letters += "s" }
        if user { letters += "u" }
        return letters.isEmpty ? nil : "-" + letters
    }
}

/// Runs and supervises a single `caffeinate` process.
@MainActor
final class Caffeinator: ObservableObject {
    enum EndReason {
        case stoppedByUser
        case timeUp
        case processExited
    }

    @Published private(set) var isAwake = false
    /// When the current session ends; nil while awake means "until stopped".
    @Published private(set) var endDate: Date?
    @Published var flags: KeepAwakeFlags {
        didSet {
            guard flags != oldValue else { return }
            Self.saveFlags(flags)
            if isAwake { relaunch() }
        }
    }

    /// Called whenever a session ends, for any reason.
    var onSessionEnded: ((EndReason) -> Void)?

    private var process: Process?
    private var endTimer: Timer?

    init() {
        flags = Self.loadFlags()
    }

    /// Starts (or restarts) keeping the Mac awake. `duration` nil = until stopped.
    func start(for duration: TimeInterval?) {
        endDate = duration.map { Date().addingTimeInterval(max(1, $0)) }
        isAwake = true
        relaunch()
        scheduleEndTimer()
    }

    /// Starts a session that ends at a wall-clock time.
    func start(until date: Date) {
        start(for: date.timeIntervalSinceNow)
    }

    func stop() {
        end(.stoppedByUser)
    }

    var remaining: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSinceNow) }
    }

    /// The command line Cappy is running (or would run), for display.
    var commandLine: String {
        var parts = ["caffeinate"]
        if let flag = flags.argument { parts.append(flag) }
        if let remaining { parts += ["-t", String(Int(remaining.rounded(.up)))] }
        return parts.joined(separator: " ")
    }

    // MARK: - Process management

    private func relaunch() {
        killProcess()

        var args: [String] = []
        if let flag = flags.argument { args.append(flag) }
        if let remaining {
            guard remaining > 0 else { end(.timeUp); return }
            args += ["-t", String(Int(remaining.rounded(.up)))]
        }
        // Tie caffeinate's life to ours so a crash never leaves the Mac stuck awake.
        args += ["-w", String(ProcessInfo.processInfo.processIdentifier)]

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        proc.arguments = args
        proc.terminationHandler = { [weak self] finished in
            Task { @MainActor in self?.processDidExit(finished) }
        }

        do {
            try proc.run()
            process = proc
        } catch {
            NSLog("Cappy: couldn't start caffeinate: \(error)")
            end(.processExited)
        }
    }

    private func processDidExit(_ finished: Process) {
        // Ignore processes we replaced or stopped on purpose.
        guard finished === process else { return }
        process = nil
        if let endDate, endDate.timeIntervalSinceNow <= 1 {
            end(.timeUp)
        } else {
            end(.processExited)
        }
    }

    private func killProcess() {
        guard let proc = process else { return }
        process = nil
        if proc.isRunning { proc.terminate() }
    }

    private func scheduleEndTimer() {
        endTimer?.invalidate()
        endTimer = nil
        guard let endDate else { return }
        // Wall-clock backstop: if the Mac slept through the end, this fires on wake.
        let timer = Timer(fire: endDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.end(.timeUp) }
        }
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
    }

    private func end(_ reason: EndReason) {
        guard isAwake else { return }
        killProcess()
        endTimer?.invalidate()
        endTimer = nil
        isAwake = false
        endDate = nil
        onSessionEnded?(reason)
    }

    // MARK: - Persistence

    private static let flagsKey = "keepAwakeFlags"

    private static func loadFlags() -> KeepAwakeFlags {
        guard let data = UserDefaults.standard.data(forKey: flagsKey),
              let flags = try? JSONDecoder().decode(KeepAwakeFlags.self, from: data)
        else { return KeepAwakeFlags() }
        return flags
    }

    private static func saveFlags(_ flags: KeepAwakeFlags) {
        if let data = try? JSONEncoder().encode(flags) {
            UserDefaults.standard.set(data, forKey: flagsKey)
        }
    }
}
