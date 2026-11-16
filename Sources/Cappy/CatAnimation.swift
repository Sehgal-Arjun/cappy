import AppKit

/// Decides which frame the cat shows at a given moment, so the menu bar
/// icon and the cat in the dropdown always move together.
enum CatAnimation {
    enum Pose { case idle, groom, sleep }

    struct Frame: Equatable {
        let pose: Pose
        let index: Int
    }

    static func strip(for pose: Pose) -> SpriteStrip {
        switch pose {
        case .idle: CatSprites.idle
        case .groom: CatSprites.groom
        case .sleep: CatSprites.sleep
        }
    }

    static func frame(awake: Bool, at time: TimeInterval) -> Frame {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return Frame(pose: awake ? .idle : .sleep, index: 0)
        }
        guard awake else { return frame(.sleep, at: time) }

        // Sit and look around for a while, then give a paw a quick lick.
        let cycle: TimeInterval = 11
        let groomLength = loopLength(.groom) * 2
        let t = time.truncatingRemainder(dividingBy: cycle)
        if t < cycle - groomLength {
            return frame(.idle, at: t)
        }
        return frame(.groom, at: t - (cycle - groomLength))
    }

    static func image(for frame: Frame) -> CGImage? {
        let frames = strip(for: frame.pose).frames
        return frames.indices.contains(frame.index) ? frames[frame.index] : nil
    }

    private static func frame(_ pose: Pose, at time: TimeInterval) -> Frame {
        let s = strip(for: pose)
        let count = max(1, s.frames.count)
        return Frame(pose: pose, index: Int(time / s.frameDuration) % count)
    }

    private static func loopLength(_ pose: Pose) -> TimeInterval {
        let s = strip(for: pose)
        return s.frameDuration * Double(max(1, s.frames.count))
    }
}
