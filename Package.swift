// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PhotosMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PhotosMCP", targets: ["PhotosMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "PhotosMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/PhotosMCP",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
