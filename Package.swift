// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ConcordiumSwiftSdk",
    platforms: [
        // To be kept in sync with README.
        .iOS(.v15),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ConcordiumSwiftSdk",
            targets: ["ConcordiumSwiftSdk"]
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
            name: "ConcordiumSwiftSdk",
            dependencies: [
                "Base58Check",
                "ConcordiumWalletCrypto",
                .product(name: "GRPC", package: "grpc-swift"),
                "SwiftFormat",
            ]
        ),
        .testTarget(
            name: "ConcordiumSwiftSdkTests",
            dependencies: [
                "ConcordiumSwiftSdk",
            ]
        ),
    ]
)
