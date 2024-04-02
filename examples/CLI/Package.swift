// swift-tools-version: 5.9

import Foundation
import PackageDescription

let package = Package(
    name: "concordium-example-client",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        overridableSDKDependency(
            url: "https://github.com/Concordium/concordium-swift-sdk.git",
            branch: "main"
        ),
    ],
    targets: [
        .executableTarget(
            name: "concordium-example-client",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Concordium", package: "concordium-swift-sdk"),
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
