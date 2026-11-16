import Foundation

/// The preset lengths shown as chips in the menu.
enum DurationChoice: String, CaseIterable, Identifiable {
    case m15, m30, h1, h2, h4, forever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .m15: "15m"
        case .m30: "30m"
        case .h1: "1h"
        case .h2: "2h"
        case .h4: "4h"
        case .forever: "∞"
        }
    }

    /// nil = until stopped
    var seconds: TimeInterval? {
        switch self {
        case .m15: 15 * 60
        case .m30: 30 * 60
        case .h1: 60 * 60
        case .h2: 2 * 60 * 60
        case .h4: 4 * 60 * 60
        case .forever: nil
        }
    }
}

/// Small persisted preferences that aren't owned by Caffeinator.
@MainActor
final class Settings: ObservableObject {
    @Published var duration: DurationChoice {
        didSet { UserDefaults.standard.set(duration.rawValue, forKey: Keys.duration) }
    }

    private enum Keys {
        static let duration = "durationChoice"
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Keys.duration) ?? ""
        duration = DurationChoice(rawValue: raw) ?? .h2
    }
}

enum TimeFormat {
    /// "1:42" or "14m" for the menu bar.
    static func short(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return String(format: "%d:%02d", h, m) }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
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
