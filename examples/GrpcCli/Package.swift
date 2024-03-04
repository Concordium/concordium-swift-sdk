// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GrpcCli",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/Electric-Coin-Company/MnemonicSwift", from: "2.2.4"),
        .package(url: "https://github.com/vapor/vapor", from: "4.92.4"),
        .package(path: "../.."), // TODO: Revert before merging!
    ],
    targets: [
        .executableTarget(
            name: "GrpcCli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ConcordiumSwiftSdk", package: "concordium-swift-sdk"),
                "MnemonicSwift",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
    ]
)
