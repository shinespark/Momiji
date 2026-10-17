// swift-tools-version: 6.1

import PackageDescription

let azooKey: Target.Dependency = .product(
    name: "KanaKanjiConverterModuleWithDefaultDictionary",
    package: "AzooKeyKanaKanjiConverter"
)

let package = Package(
    name: "Momiji",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            revision: "ad714fea8cb2fe113aea86ba5c42563cdaf77cfb",
            traits: ["Zenzai"]
        ),
    ],
    targets: [
        .target(name: "MomijiCore"),
        .target(
            name: "MomijiConverter",
            dependencies: ["MomijiCore", azooKey],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "momiji-try",
            dependencies: ["MomijiCore", "MomijiConverter"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "MomijiCoreTests",
            dependencies: ["MomijiCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MomijiConverterTests",
            dependencies: ["MomijiConverter"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
