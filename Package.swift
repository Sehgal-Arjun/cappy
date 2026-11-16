// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Cappy",
    platforms: [.macOS(.v13)],
    targets: [
        // No SwiftPM resources here on purpose: scripts/build-app.sh copies
        // Resources/ into the .app and the code loads it via Bundle.main.
        .executableTarget(name: "Cappy", path: "Sources/Cappy")
    ]
)
