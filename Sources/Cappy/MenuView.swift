import SwiftUI

private let accent = Color(red: 0.85, green: 0.41, blue: 0.17)

struct MenuView: View {
    @ObservedObject var caffeinator: Caffeinator
    @ObservedObject var settings: Settings
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
                Button("Wake up") { caffeinator.start(for: settings.duration.seconds) }
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
                ForEach(DurationChoice.allCases) { choice in
                    Button(choice.label) { pick(choice) }
                        .buttonStyle(ChipButtonStyle(selected: settings.duration == choice))
                        .accessibilityAddTraits(settings.duration == choice ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func pick(_ choice: DurationChoice) {
        settings.duration = choice
        // Already awake: restart the clock with the new length.
        if caffeinator.isAwake { caffeinator.start(for: choice.seconds) }
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let frame = CatAnimation.frame(awake: awake, at: t)
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.07))
                    .frame(height: 2)
                    .padding(.bottom, 14)
                if let image = CatAnimation.image(for: frame) {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: SpriteStrip.frameSize.width * 4,
                               height: SpriteStrip.frameSize.height * 4)
                        .padding(.bottom, 15)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(awake ? Color(red: 0.965, green: 0.937, blue: 0.886)
                                : Color(red: 0.906, green: 0.898, blue: 0.933))
            )
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
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
