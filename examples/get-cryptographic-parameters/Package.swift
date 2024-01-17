// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "concordium-swift-sdk-cli",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", revision: "8700cc6316d24057e9e30445b31ef07c28ec992f"),
    ],
    targets: [
        .executableTarget(
            name: "concordium-swift-sdk-cli",
            dependencies: [
                .product(name: "ConcordiumSwiftSDK", package: "concordium-swift-sdk"),
            ]
        ),
    ]
)
