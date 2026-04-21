// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageDeck",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "UsageDeck", targets: ["UsageDeck"]),
        .library(name: "UsageDeckCore", targets: ["UsageDeckCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "UsageDeckCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        .executableTarget(
            name: "UsageDeck",
            dependencies: [
                "UsageDeckCore",
            ],
            path: "Sources/UsageDeck",
            exclude: ["Plist/Info.plist"],
            resources: [
                .process("Resources"),
            ]
        ),

        .testTarget(
            name: "UsageDeckCoreTests",
            dependencies: ["UsageDeckCore"],
            path: "Tests/UsageDeckCoreTests"
        ),
    ]
)
