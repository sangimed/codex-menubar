// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CodexMenuBar",
            targets: ["CodexMenuBar"]
        ),
        .library(
            name: "CodexMenuBarCore",
            targets: ["CodexMenuBarCore"]
        )
    ],
    targets: [
        .target(
            name: "CodexMenuBarCore"
        ),
        .executableTarget(
            name: "CodexMenuBar",
            dependencies: ["CodexMenuBarCore"]
        ),
        .testTarget(
            name: "CodexMenuBarCoreTests",
            dependencies: ["CodexMenuBarCore"]
        ),
        .testTarget(
            name: "CodexMenuBarTests",
            dependencies: ["CodexMenuBar"]
        )
    ]
)
