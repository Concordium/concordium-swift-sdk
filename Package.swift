// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ConcordiumSwiftSDK",
    platforms: [
        // To be kept in sync with README.
        .iOS(.v15),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ConcordiumSwiftSDK",
            targets: ["ConcordiumSwiftSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/anquii/Base58Check.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.15.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.53.0"),
        .package(path: "./lib/crypto/ConcordiumWalletCrypto"),
    ],
    targets: [
        .target(
            name: "ConcordiumSwiftSDK",
            dependencies: [
                "Base58Check",
                "ConcordiumWalletCrypto",
//                        .product(name: "ConcordiumWalletCrypto", package: "ConcordiumWalletCrypto"),
                .product(name: "GRPC", package: "grpc-swift"),
                "SwiftFormat",
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
