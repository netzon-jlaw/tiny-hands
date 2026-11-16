// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TinyHands",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TinyHands",
            path: "Sources/TinyHands",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
