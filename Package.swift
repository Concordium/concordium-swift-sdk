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
            .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.15.0"),
            .package(url: "https://github.com/anquii/Base58Check.git", from: "1.0.0"),
        ],
        targets: [
            .target(
                    name: "ConcordiumSwiftSDK",
                    dependencies: [
                        .product(name: "GRPC", package: "grpc-swift"),
                        "Base58Check",
                    ]
            ),
            .testTarget(
                    name: "ConcordiumSwiftSDKTests",
                    dependencies: [
                        "ConcordiumSwiftSDK",
                    ]
            ),
        ]
)
