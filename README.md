# Concordium Swift SDK

**STATUS: EARLY DEVELOPMENT**

An SDK for applications written in the [Swift Programming Language](https://www.swift.org/) to
interact with the Concordium Blockchain.

The main purpose of the SDK is to facilitate development of mobile wallet apps for iOS devices.

### Supported platforms

- iOS 15+
- macOS 10.15+

## Usage

*No tags have been added to "publish" a build yet. The following is unverified and is only going to work once v1.0 has been published.*

The SDK is available as a SwiftPM package hosted on GitHub as this repository.
To include it as a dependency, add the following 

```swift
.package(url: "https://github.com/Concordium/concordium-swift-sdk.git", from: "1.0"),
```

and adding

```swift
.product(name: "ConcordiumSwiftSDK", package: "concordium-swift-sdk"),
```

to the `dependencies` list of the appropriate `target`.

## Development

### Source code formatting

The source code is formatted according to the default rules of [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat).

The CI workflow [`Build and test`](https://github.com/Concordium/concordium-swift-sdk/blob/main/.github/workflows/build%2Btest.yml)
checks that the code base is correct formated before PRs are merged.

The formatter has been integrated as a [Swift Package Manger plugin](https://github.com/nicklockwood/SwiftFormat#swift-package-manager-plugin).
It's possible to run the tool in a variety of ways (see the previous link for all options).
An easy option is

```shell
swift package plugin --allow-writing-to-package-directory swiftformat
```

It may also be invoked directly from XCode by right-clicking on package root (i.e. `concordium-swift-sdk`) in the Project Navigator pane.
The tool is then listed under "SwiftFormat" as "SwiftFormatPlugin" in the context menu for formatting the entire project.
