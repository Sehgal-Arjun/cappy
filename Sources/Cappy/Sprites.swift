import AppKit

/// One row of equally sized pixel-art frames, e.g. Resources/Sprites/idle.png.
struct SpriteStrip {
    static let frameSize = CGSize(width: 32, height: 24)

    let frames: [CGImage]
    let frameDuration: TimeInterval

    init(named name: String, frameDuration: TimeInterval) {
        self.frameDuration = frameDuration
        guard let image = Self.loadImage(named: name) else {
            NSLog("Cappy: missing sprite \(name).png")
            frames = []
            return
        }
        let w = Int(Self.frameSize.width), h = Int(Self.frameSize.height)
        frames = (0..<(image.width / w)).compactMap {
            image.cropping(to: CGRect(x: $0 * w, y: 0, width: w, height: h))
        }
    }

    func frame(at time: TimeInterval) -> CGImage? {
        guard !frames.isEmpty else { return nil }
        let index = Int(time / frameDuration) % frames.count
        return frames[index]
    }

    private static func loadImage(named name: String) -> CGImage? {
        // Inside Cappy.app the strips live in Contents/Resources/Sprites.
        // Running straight from `swift run`, fall back to the repo folder.
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites"),
            URL(fileURLWithPath: "Resources/Sprites/\(name).png"),
        ]
        for case let url? in candidates {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return image
            }
        }
        return nil
    }
}

enum CatSprites {
    static let idle = SpriteStrip(named: "idle", frameDuration: 0.14)
    static let groom = SpriteStrip(named: "groom", frameDuration: 0.12)
    static let sleep = SpriteStrip(named: "sleep", frameDuration: 0.28)
}

extension CGImage {
    /// Scales pixel art with hard edges into an NSImage of the given point height.
    /// Drawn at 2x so it stays sharp on Retina menu bars.
    func pixelImage(pointHeight: CGFloat) -> NSImage {
        let scale = pointHeight / CGFloat(height)
        let size = NSSize(width: (CGFloat(width) * scale).rounded(), height: pointHeight)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(self, in: rect)
            return true
        }
        return image
    }
}
