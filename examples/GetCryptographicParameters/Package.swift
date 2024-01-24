// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GetCryptographicParameters",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "GetCryptographicParameters",
            dependencies: [
                .product(name: "ConcordiumSwiftSDK", package: "concordium-swift-sdk"),
            ]
        ),
    ]
)
