// swift-tools-version: 5.6

import Foundation
import PackageDescription

let package = Package(
    name: "concordium",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "concordium", targets: ["CLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/Electric-Coin-Company/MnemonicSwift", from: "2.2.4"),
        .package(url: "https://github.com/vapor/vapor", from: "4.92.4"),
        overridableSDKDependency(
            url: "https://github.com/Concordium/concordium-swift-sdk.git",
            branch: "main"
        ),
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Concordium", package: "concordium-swift-sdk"),
                "MnemonicSwift",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
    ]
)

func overridableSDKDependency(url: String, branch: String) -> Package.Dependency {
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
