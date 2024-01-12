// swift-tools-version: 5.6

import PackageDescription

let package = Package(
        name: "ConcordiumSwiftSDK",
        platforms: [
            .iOS(.v15),
        ],
        products: [
            .library(
                    name: "ConcordiumSwiftSDK",
                    targets: ["ConcordiumSwiftSDK"]),
        ],
        dependencies: [
            .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.15.0"),
            .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.53.0"),
        ],
        targets: [
            .target(
                    name: "ConcordiumSwiftSDK",
                    dependencies: [.product(name: "GRPC", package: "grpc-swift"), "SwiftFormat"]
            ),
            .testTarget(
                    name: "ConcordiumSwiftSDKTests",
                    dependencies: [
                        "ConcordiumSwiftSDK",
                    ]
            ),
        ]
)
