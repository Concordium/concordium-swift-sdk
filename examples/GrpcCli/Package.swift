// swift-tools-version: 5.6

import Foundation
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
        overridableSdkDependency(
            url: "https://github.com/Concordium/concordium-swift-sdk.git",
            branch: "main"
        ),
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

func overridableSdkDependency(url: String, branch: String) -> Package.Dependency {
    if let p = providedSdkPath(), !p.isEmpty {
        return .package(path: p)
    }
    return .package(url: url, branch: branch)
}

func providedSdkPath() -> String? {
    getEnv("CONCORDIUM_SDK_PATH")
}

func getEnv(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
}
