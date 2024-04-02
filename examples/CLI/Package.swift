// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "concordium-example-client",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/Electric-Coin-Company/MnemonicSwift.git", from: "2.2.4"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
//        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", branch: "main"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "concordium-example-client",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Concordium", package: "concordium-swift-sdk"),
                "MnemonicSwift",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
    ]
)
