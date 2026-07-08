// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SquishMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SquishMac", targets: ["SquishMac"])
    ],
    targets: [
        .executableTarget(
            name: "SquishMac",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SquishMacTests",
            dependencies: ["SquishMac"]
        )
    ]
)
