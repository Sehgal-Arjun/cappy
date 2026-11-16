// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Cappy",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Auto-updates. Pinned exactly; bump deliberately.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // No SwiftPM resources here on purpose: scripts/build-app.sh copies
        // Resources/ into the .app and the code loads it via Bundle.main.
        .executableTarget(
            name: "Cappy",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Cappy",
            linkerSettings: [
                // Sparkle.framework is copied into Cappy.app/Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
