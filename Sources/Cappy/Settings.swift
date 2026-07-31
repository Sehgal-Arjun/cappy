import Foundation

/// How long a session lasts: a preset chip, or until a time of day.
enum DurationChoice: String, CaseIterable, Identifiable {
    case m15, m30, h1, h2, h4, forever, until

    var id: String { rawValue }

    /// The chips in the "How long" row.
    static let presets: [DurationChoice] = [.m15, .m30, .h1, .h2, .h4, .forever]

    var label: String {
        switch self {
        case .m15: "15m"
        case .m30: "30m"
        case .h1: "1h"
        case .h2: "2h"
        case .h4: "4h"
        case .forever: "∞"
        case .until: "Until"
        }
    }

    /// Fixed length of a preset; nil for "until stopped" and "until a time".
    var presetSeconds: TimeInterval? {
        switch self {
        case .m15: 15 * 60
        case .m30: 30 * 60
        case .h1: 60 * 60
        case .h2: 2 * 60 * 60
        case .h4: 4 * 60 * 60
        case .forever, .until: nil
        }
    }
}

/// Small persisted preferences that aren't owned by Caffeinator.
@MainActor
final class Settings: ObservableObject {
    @Published var duration: DurationChoice {
        didSet { defaults.set(duration.rawValue, forKey: Keys.duration) }
    }

    /// Minutes after midnight for the "Until" choice.
    @Published var untilMinutes: Int {
        didSet { defaults.set(untilMinutes, forKey: Keys.untilMinutes) }
    }

    @Published var notifyWhenDone: Bool {
        didSet { defaults.set(notifyWhenDone, forKey: Keys.notify) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let duration = "durationChoice"
        static let untilMinutes = "untilMinutes"
        static let notify = "notifyWhenDone"
    }

    init() {
        duration = DurationChoice(rawValue: defaults.string(forKey: Keys.duration) ?? "") ?? .h2
        untilMinutes = (defaults.object(forKey: Keys.untilMinutes) as? Int) ?? 17 * 60
        notifyWhenDone = (defaults.object(forKey: Keys.notify) as? Bool) ?? true
    }

    /// Session length for the current choice; nil = until stopped.
    func sessionLength(from now: Date = Date()) -> TimeInterval? {
        switch duration {
        case .forever: return nil
        case .until: return nextUntilDate(after: now).timeIntervalSince(now)
        default: return duration.presetSeconds
        }
    }

    /// The next time the clock reads the "Until" time: later today, or tomorrow.
    func nextUntilDate(after now: Date = Date()) -> Date {
        let cal = Calendar.current
        let parts = DateComponents(hour: untilMinutes / 60, minute: untilMinutes % 60)
        return cal.nextDate(after: now, matching: parts, matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
    }

    /// The "Until" time as a Date today, for the time picker.
    var untilTime: Date {
        get {
            Calendar.current.date(bySettingHour: untilMinutes / 60, minute: untilMinutes % 60, second: 0, of: Date()) ?? Date()
        }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            untilMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}

enum TimeFormat {
    /// "1h42", "14m" or "<1m" for the menu bar. Only changes once a minute.
    static func short(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return String(format: "%dh%02d", h, m) }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    /// "1h 42m left" or "3m 20s left" for the menu.
    static func long(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return "\(h)h \(m)m left" }
        if m > 0 { return "\(m)m \(sec)s left" }
        return "\(sec)s left"
    }
}
