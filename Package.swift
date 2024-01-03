// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
        name: "concordium-swift-sdk",
        products: [
            .library(
                    name: "concordium-swift-sdk",
                    targets: ["concordium-swift-sdk"]),
        ],
        dependencies: [
            .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.15.0")
        ],
        targets: [
            .target(
                    name: "concordium-swift-sdk",
                    dependencies: [.product(name: "GRPC", package: "grpc-swift")]
            ),
            .testTarget(
                    name: "concordium-swift-sdkTests",
                    dependencies: [
                        "concordium-swift-sdk",
                    ]
            ),
        ]
)
