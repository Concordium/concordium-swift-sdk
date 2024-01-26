// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ConcordiumWalletCrypto",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ConcordiumWalletCrypto",
            targets: ["ConcordiumWalletCrypto"]
        ),
    ],
    dependencies: [],
    targets: [
        // TODO: Generate using build plugin.
        .binaryTarget(name: "RustFramework", path: "./RustFramework.xcframework"),
        // TODO: Generate using build plugin.
        .target(
            name: "ConcordiumWalletCrypto",
            dependencies: [
                .target(name: "RustFramework"),
            ]
        ),
    ]
)
