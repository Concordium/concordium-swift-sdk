# Concordium Swift SDK

**STATUS: EARLY DEVELOPMENT**

An SDK for applications written in the [Swift Programming Language](https://www.swift.org/) to
interact with the [Concordium Blockchain](https://concordium.com).

The main purpose of the SDK is to facilitate development of mobile wallet apps for iOS devices.

Once the project is ready for production, it will replace the existing
[`ConcordiumWalletCrypto`](https://github.com/Concordium/concordium-wallet-crypto-swift) library
which is currently used in the [iOS reference wallet](https://github.com/Concordium/concordium-reference-wallet-ios/).

### Supported platforms

- iOS 15+
- macOS 10.15+

## Usage

*No tags have been added to "publish" a build yet. The following is only going to work once v1.0 has been published.
To use it in the current, unfinished state, replace `"1.0"` with `"main"`.*

The SDK is available as a [SwiftPM package](https://developer.apple.com/documentation/xcode/swift-packages)
hosted on GitHub as this repository.
To include it as a dependency, add the following 

```swift
.package(url: "https://github.com/Concordium/concordium-swift-sdk.git", from: "1.0")
```

and adding

```swift
.product(name: "ConcordiumSwiftSDK", package: "concordium-swift-sdk")
```

to the `dependencies` list of the appropriate `target`.

## Development

### Build Rust bindings

Concordium specific cryptographic functions are implemented in Rust and shared between all kinds of Concordium products.
This SDK includes a thin wrapper for providing bindings to the Rust library
[`wallet_library`](https://github.com/Concordium/concordium-base/tree/main/rust-src/wallet_library)
which exposes functions specifically relevant for wallets.

These bindings are located in `./lib/crypto` and compiled into an
[XCFramework](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages).
The SDK pulls in this framework from a local path, so the bindings have to built manually before the SDK can be used.

Building is only a matter of installing `cargo-swift` and invoking the Make target

```shell
make build-crypto
```

This will place the target framework in `./lib/crypto/ConcordiumWalletCrypto`.

### Build and test SDK

With the Rust bindings in place, the SDK is built and tests executed using `swift test`.
It's not necessary to build the project in order to use it in other projects:
Just declare a dependency as explained in [usage](#usage).
The SDK will get compiled as part of the build process of the executable.

TODO: This means that we'll either have to add steps in `Package.swift` for automatically building the binaries (if possible)
or push them to some specific location
(like we did with [`concordium-wallet-crypto-swift`](https://github.com/Concordium/concordium-wallet-crypto-swift)).
This could be a GitHub release/package or S3.

### Source code formatting

The source code is formatted according to the default rules of [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat).

The CI workflow [`Build and test`](https://github.com/Concordium/concordium-swift-sdk/blob/main/.github/workflows/build%2Btest.yml)
checks that the code base is correctly formated before PRs are merged.

The formatter has been integrated as a
[Swift Package Manger plugin](https://github.com/nicklockwood/SwiftFormat#swift-package-manager-plugin).
It's possible to run the tool in a variety of ways (see the previous link for all options).
The easiest option is to run it on the command line via

```shell
make fmt
```

It may also be [invoked directly from XCode](https://github.com/nicklockwood/SwiftFormat#trigger-plugin-from-xcode)
by right-clicking on package root (i.e. `concordium-swift-sdk`) in the Project Navigator pane.
The tool is then listed under "SwiftFormat" as "SwiftFormatPlugin" in the context menu for formatting the entire project.
