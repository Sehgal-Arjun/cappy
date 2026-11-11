import SwiftUI

private let accent = Color(red: 0.85, green: 0.41, blue: 0.17)

struct MenuView: View {
    @ObservedObject var caffeinator: Caffeinator
    @ObservedObject var settings: Settings
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var notifier: Notifier
    @State private var untilRestart: DispatchWorkItem?
    /// Starts a session using the current duration choice.
    let start: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatStage(awake: caffeinator.isAwake)
            header
            Divider()
            durations
            Divider()
            flags
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .tint(accent)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caffeinator.isAwake ? "Cappy is up" : "Cappy is napping")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            if caffeinator.isAwake {
                Button("Let it sleep") { caffeinator.stop() }
                    .buttonStyle(PillButtonStyle(filled: false))
            } else {
                Button("Wake up", action: start)
                    .buttonStyle(PillButtonStyle(filled: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 4)
    }

    private var subtitle: String {
        guard caffeinator.isAwake else { return "Your Mac can sleep as usual" }
        guard let remaining = caffeinator.remaining else { return "Keeping your Mac awake" }
        return TimeFormat.long(remaining)
    }

    // MARK: Durations

    private var durations: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel("How long")
            HStack(spacing: 5) {
                ForEach(DurationChoice.presets) { choice in
                    chip(choice)
                }
            }
            HStack(spacing: 8) {
                chip(.until)
                    .frame(width: 64)
                DatePicker("Until", selection: untilBinding,
                           in: Settings.untilEarliest...Settings.untilLimit,
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                Spacer(minLength: 0)
            }
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                let offset = settings.untilDayOffset()
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        ForEach([(0, "Today"), (1, "Tomorrow"), (2, "Day after")], id: \.0) { day, label in
                            Button(label) { pickDay(day) }
                                .buttonStyle(ChipButtonStyle(selected: settings.duration == .until && offset == day, small: true))
                                .fixedSize()
                        }
                    }
                    Text(untilSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 4)
    }

    /// "Wed 5:00 pm · in 1d 4h", so a date picked in the stepper is easy to sanity-check.
    private var untilSummary: String {
        let now = Date()
        let target = settings.effectiveUntilDate(after: now)
        let when = target.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        // Round up to whole minutes so 1h 59m 30s reads "2h 0m", not "1h 59m".
        let s = Int((target.timeIntervalSince(now) / 60).rounded(.up)) * 60
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        let gap = d > 0 ? "\(d)d \(h)h" : h > 0 ? "\(h)h \(m)m" : "\(max(m, 1))m"
        return "\(when) · in \(gap)"
    }

    private func pickDay(_ day: Int) {
        settings.setUntilDay(day)
        pick(.until)
    }

    private func chip(_ choice: DurationChoice) -> some View {
        Button(choice.label) { pick(choice) }
            .buttonStyle(ChipButtonStyle(selected: settings.duration == choice))
            .accessibilityAddTraits(settings.duration == choice ? .isSelected : [])
    }

    /// Editing the time also selects "Until". While awake, the session is
    /// restarted once the user stops clicking, not on every step.
    private var untilBinding: Binding<Date> {
        Binding(
            get: { settings.effectiveUntilDate() },
            set: { newValue in
                let before = settings.untilDate
                settings.untilDate = newValue
                guard settings.untilDate != before || settings.duration != .until else { return }
                settings.duration = .until
                untilRestart?.cancel()
                guard caffeinator.isAwake else { return }
                let work = DispatchWorkItem { [start] in start() }
                untilRestart = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            }
        )
    }

    private func pick(_ choice: DurationChoice) {
        settings.duration = choice
        // Already awake: restart the clock with the new length.
        if caffeinator.isAwake { start() }
    }

    // MARK: Flags

    private var flags: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel("While awake, keep")
            flagRow("Screen on", "-d", \.display)
            flagRow("Mac from idling", "-i", \.idle)
            flagRow("Disks spinning", "-m", \.disk)
            flagRow("System on, when plugged in", "-s", \.system)
            flagRow("You marked as active", "-u", \.user)
            Text(caffeinator.commandLine)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                .padding(.top, 6)
        }
        .padding(.horizontal, 4)
    }

    /// With every flag off caffeinate quietly falls back to -i, so the last
    /// switch that's on can't be turned off.
    private func flagRow(_ title: String, _ flag: String, _ key: WritableKeyPath<KeepAwakeFlags, Bool>) -> some View {
        let isOn = caffeinator.flags[keyPath: key]
        let isLast = isOn && caffeinator.flags.argument?.count == 2
        return FlagRow(title: title, flag: flag, isOn: $caffeinator.flags[dynamicMember: key])
            .disabled(isLast)
            .help(isLast ? "Keep at least one on" : "")
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingRow(title: "Open at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
            if loginItem.needsApproval {
                Button("Allow Cappy in Login Items settings…") { loginItem.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
            if let message = loginItem.errorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            SettingRow(title: "Tell me when time's up", isOn: Binding(
                get: { settings.notifyWhenDone },
                set: {
                    settings.notifyWhenDone = $0
                    if $0 { notifier.requestPermission() }
                }
            ))
            if settings.notifyWhenDone && notifier.isBlocked {
                Button("Notifications are off for Cappy. Turn them on…") { notifier.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .padding(.horizontal, 4)
            }
            quitButton
        }
    }

    private var quitButton: some View {
        Button(action: quit) {
            HStack {
                Text("Quit Cappy")
                Spacer()
                Text("⌘Q").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

// MARK: - Pieces

private struct CatStage: View {
    let awake: Bool
    private static let floor: CGFloat = 20

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let frame = CatAnimation.frame(awake: awake, at: t)
            ZStack(alignment: .bottom) {
                // A floor for the cat to sit on, like the shelf in the DMG.
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black.opacity(0.10)).frame(height: 2)
                    Rectangle().fill(Color.black.opacity(0.05))
                }
                .frame(height: Self.floor)
                if let image = CatAnimation.image(for: frame) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: SpriteStrip.frameSize.width * 4,
                               height: SpriteStrip.frameSize.height * 4)
                        // Paws rest just over the floor's top edge.
                        .padding(.bottom, Self.floor - 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 122)
            .background(awake ? Color(red: 0.965, green: 0.937, blue: 0.886)
                              : Color(red: 0.906, green: 0.898, blue: 0.933))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.3), value: awake)
        }
        .accessibilityElement()
        .accessibilityLabel(awake ? "Cappy, sitting up and awake" : "Cappy, curled up asleep")
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct FlagRow: View {
    let title: String
    let flag: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(flag)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .frame(minHeight: 26)
    }
}

private struct SettingRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .frame(minHeight: 26)
        .padding(.horizontal, 4)
    }
}

private struct PillButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .foregroundStyle(filled ? Color(nsColor: .windowBackgroundColor) : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(filled ? Color.primary : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(filled ? Color.primary : Color.primary.opacity(0.18))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let selected: Bool
    /// Compact, content-sized chip (the Until day shortcuts).
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 11 : 12, weight: .semibold))
            .padding(.horizontal, small ? 8 : 0)
            .frame(maxWidth: small ? nil : .infinity)
            .frame(height: small ? 22 : 28)
            .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selected ? Color.primary : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(selected ? Color.primary : Color.primary.opacity(0.14))
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
