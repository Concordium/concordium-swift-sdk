// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ConcordiumExampleClient",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "concordium-example-client", targets: ["ConcordiumExampleClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
//        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", branch: "main"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ConcordiumExampleClient",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Concordium", package: "concordium-swift-sdk"),
            ]
        ),
    ]
)
