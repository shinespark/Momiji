// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Momiji",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MomijiCore"),
        .testTarget(
            name: "MomijiCoreTests",
            dependencies: ["MomijiCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
