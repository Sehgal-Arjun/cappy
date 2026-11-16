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

    /// The "Until" choice: a date and time, up to a week ahead.
    @Published var untilDate: Date {
        didSet { defaults.set(untilDate.timeIntervalSince1970, forKey: Keys.untilDate) }
    }

    @Published var notifyWhenDone: Bool {
        didSet { defaults.set(notifyWhenDone, forKey: Keys.notify) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let duration = "durationChoice"
        static let untilDate = "untilDate"
        static let legacyUntilMinutes = "untilMinutes"
        static let notify = "notifyWhenDone"
    }

    init() {
        duration = DurationChoice(rawValue: defaults.string(forKey: Keys.duration) ?? "") ?? .h2
        if let stamp = defaults.object(forKey: Keys.untilDate) as? Double {
            untilDate = Date(timeIntervalSince1970: stamp)
        } else {
            // 1.0.0 stored only a time of day (default 5 pm).
            let minutes = (defaults.object(forKey: Keys.legacyUntilMinutes) as? Int) ?? 17 * 60
            untilDate = Self.next(hour: minutes / 60, minute: minutes % 60, after: Date())
        }
        notifyWhenDone = (defaults.object(forKey: Keys.notify) as? Bool) ?? true
    }

    /// Latest "Until" the picker allows: Cappy's longest session.
    static var untilLimit: Date { Date().addingTimeInterval(Caffeinator.maxDuration) }

    /// Earliest "Until" the picker allows: the start of the next minute, so
    /// clamping never stores a time with seconds that's already gone by.
    static var untilEarliest: Date { nextMinute(after: Date()) }

    private static func nextMinute(after now: Date) -> Date {
        let cal = Calendar.current
        return cal.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(60)
    }

    /// Session length for the current choice; nil = until stopped.
    func sessionLength(from now: Date = Date()) -> TimeInterval? {
        switch duration {
        case .forever: return nil
        case .until: return effectiveUntilDate(after: now).timeIntervalSince(now)
        default: return duration.presetSeconds
        }
    }

    /// The saved Until date, or, once it's gone by, the next time the clock
    /// reads that time of day. Never more than a week out.
    func effectiveUntilDate(after now: Date = Date()) -> Date {
        if untilDate > now {
            return min(untilDate, now.addingTimeInterval(Caffeinator.maxDuration))
        }
        // Only just passed (e.g. picked "now" a moment ago): mean the next
        // minute, not this time tomorrow.
        if now.timeIntervalSince(untilDate) < 120 {
            return Self.nextMinute(after: now)
        }
        let c = Calendar.current.dateComponents([.hour, .minute], from: untilDate)
        return Self.next(hour: c.hour ?? 17, minute: c.minute ?? 0, after: now)
    }

    /// Moves Until to `daysFromToday` (0 = today), keeping its time of day.
    /// "Today" at a time that's already passed becomes the first full hour at
    /// least half an hour away, or 11:59 pm if that would spill into tomorrow.
    func setUntilDay(_ daysFromToday: Int, now: Date = Date()) {
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute], from: untilDate)
        let day = cal.date(byAdding: .day, value: daysFromToday, to: cal.startOfDay(for: now)) ?? now
        var target = cal.date(bySettingHour: time.hour ?? 17, minute: time.minute ?? 0, second: 0, of: day) ?? now
        if target <= now {
            let soon = now.addingTimeInterval(30 * 60)
            let hour = cal.nextDate(after: soon, matching: DateComponents(minute: 0), matchingPolicy: .nextTime)
                ?? soon
            let lastMinute = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? hour
            target = cal.isDate(hour, inSameDayAs: now) ? hour : max(lastMinute, Self.nextMinute(after: now))
        }
        untilDate = target
    }

    /// Days from today to the effective Until date (0 = today, 1 = tomorrow…).
    func untilDayOffset(now: Date = Date()) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                  to: cal.startOfDay(for: effectiveUntilDate(after: now))).day ?? 0
    }

    private static func next(hour: Int, minute: Int, after now: Date) -> Date {
        Calendar.current.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute),
                                  matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
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
