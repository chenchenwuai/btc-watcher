// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BTCMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BTCMenuBar",
            path: ".",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
