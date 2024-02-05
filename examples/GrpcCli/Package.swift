// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GrpcCli",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", branch: "CBW-1565-send_account_transaction"), // TODO: Revert before merging!
    ],
    targets: [
        .executableTarget(
            name: "GrpcCli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ConcordiumSwiftSdk", package: "concordium-swift-sdk"),
            ]
        ),
    ]
)
