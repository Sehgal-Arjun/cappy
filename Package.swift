// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Cappy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Cappy", path: "Sources/Cappy")
    ]
)
