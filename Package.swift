// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Janus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Janus",
            path: "Sources/Janus",
            exclude: [
                "Resources/Info.plist",
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "JanusTests",
            dependencies: ["Janus"],
            path: "Tests/JanusTests"
        )
    ]
)
