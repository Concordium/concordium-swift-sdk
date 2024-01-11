// swift-tools-version: 5.6

import PackageDescription

let package = Package(
        name: "ConcordiumSwiftSDK",
        platforms: [
            .macOS(.v10_15),
            .iOS(.v15),
        ],
        products: [
            .library(
                    name: "ConcordiumSwiftSDK",
                    targets: ["ConcordiumSwiftSDK"]),
        ],
        dependencies: [
            .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.15.0")
        ],
        targets: [
            .target(
                    name: "ConcordiumSwiftSDK",
                    dependencies: [.product(name: "GRPC", package: "grpc-swift")]
            ),
            .testTarget(
                    name: "ConcordiumSwiftSDKTests",
                    dependencies: [
                        "ConcordiumSwiftSDK",
                    ]
            ),
        ]
)
