// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Pulse",
            targets: ["Pulse"]
        )
    ],
    targets: [
        .target(
            name: "Pulse",
            path: "Sources/Pulse"
        ),
        .executableTarget(
            name: "PulseDemo",
            dependencies: ["Pulse"],
            path: "Sources/PulseDemo"
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["Pulse"],
            path: "Tests/PulseTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
