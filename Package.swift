// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StayConnected",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "StayConnectedCore", targets: ["StayConnectedCore"]),
        .executable(name: "StayConnected", targets: ["StayConnected"]),
        .executable(name: "StayConnectedCoreChecks", targets: ["StayConnectedCoreChecks"])
    ],
    targets: [
        .target(name: "StayConnectedCore"),
        .executableTarget(
            name: "StayConnected",
            dependencies: ["StayConnectedCore"]
        ),
        .executableTarget(
            name: "StayConnectedCoreChecks",
            dependencies: ["StayConnectedCore"],
            path: "Tests/StayConnectedCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
