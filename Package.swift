// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Janus",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Janus",
            path: "Sources/Janus",
            exclude: [
                "Resources/Info.plist",
            ],
            resources: [
                // Process the whole Resources dir so Assets.xcassets *and* the
                // .lproj localization folders are bundled together.
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "JanusTests",
            dependencies: ["Janus"],
            path: "Tests/JanusTests"
        )
    ]
)
