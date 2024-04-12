// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ConcordiumExampleDocSnippets",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/Electric-Coin-Company/MnemonicSwift.git", from: "2.2.4"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "IdentityCreation",
            dependencies: ["Common"]
        ),
        .executableTarget(
            name: "SignAndSendTransfer",
            dependencies: ["Common"]
        ),
        .target(
            name: "Common",
            dependencies: [
                .product(name: "Concordium", package: "concordium-swift-sdk"),
                "MnemonicSwift",
            ]
        ),
    ]
)
