# Concordium Swift SDK

An SDK for applications written in the [Swift Programming Language](https://www.swift.org/) to
interact with the [Concordium Blockchain](https://concordium.com).

The main purpose of the SDK is to facilitate development of mobile wallet apps for iOS devices.

Features:

- Creation and recovery of seed based identities.
- Creation and deployment of seed based credentials/accounts.
- Construction, signing, and sending of transfer transactions (with optional memo) from legacy or seed based accounts.
- Support for signing arbitrary binary messages.
- Support for decrypting and using accounts created using the legacy wallet.
- Utilities for working with amounts in CCD and fungible CIS-2 tokens of arbitrary size.

### Cryptographic functions

Concordium specific cryptographic functions that are implemented in Rust are exposed as a separate Swift library
[`ConcordiumWalletCrypto`](https://github.com/Concordium/concordium-wallet-crypto-swift).
That library [used to](https://github.com/Concordium/concordium-wallet-crypto-swift?tab=readme-ov-file#prior-usage)
merely host a SwiftPM package for exposing a single binary artifact of an older crypto library
which is still used in the [iOS reference wallet](https://github.com/Concordium/concordium-reference-wallet-ios/).

This SDK is intended to replace this old library, but hasn't yet reached full feature parity
([#42](https://github.com/Concordium/concordium-swift-sdk/issues/42)).

### Supported platforms

- iOS 15+
- macOS 10.15+ (macOS 12+ to build)

## Usage

The SDK is available as a [SwiftPM package](https://developer.apple.com/documentation/xcode/swift-packages)
hosted on GitHub as this repository.
To include it as a dependency, add the following 

```swift
.package(url: "https://github.com/Concordium/concordium-swift-sdk.git", from: "<version>")
```

where `<version>` is replaced by an actual version (see tags/releases on GitHub). Then add

```swift
.product(name: "Concordium", package: "concordium-swift-sdk")
```

to the `dependencies` list of the appropriate `target`.

## Examples

The repository includes some example projects that show how to integrate the SDK into different kinds of applications:

- [DocSnippets](./examples/DocSnippets):
  Example snippets of code to be directly copied into documentation while being sure that they compile successfully.
- [CLI](./examples/CLI):
  A simple client that demonstrates how to use the SDK in a terminal-based context.
  It's also used to exercise the gRPC client in ways that are hard to cover with unit tests.

An example wallet app is currently in development.

## Documentation

See the [developer documentation site](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk.html)
for collected documentation of the various Wallet SDKs.

## Development

### Build Rust bindings

The Rust bindings are located in [`concordium-wallet-crypto-swift`](https://github.com/Concordium/concordium-wallet-crypto-swift).
which also hosts the Swift package `ConcordiumWalletCrypto` for exposing the compiled binaries to Swift.
By default, this precompiled framework is downloaded from GitHub.
Use the environment variable `CONCORDIUM_WALLET_CRYPTO_PATH` to use a local checkout of this project during development.
This will also make it resolve the binary framework to the default target location when compiled locally
(`./generated/ConcordiumWalletCryptoUniffi.xcframework` relative to the crypto project root).
Use the environment variable `CONCORDIUM_WALLET_CRYPTO_FRAMEWORK_PATH` to override this location
or define the variable with empty value to disable the behavior and not use a local framework.

In conclusion, assuming that `concordium-wallet-crypto-swift` is checkout out right next to this project
(and `make framework` has been run), then the command
```shell
CONCORDIUM_WALLET_CRYPTO_PATH=../concordium-wallet-crypto-swift swift test
```
will build and test the project using the local crypto package and the binary framework compiled locally from it.

To load local version of `ConcordiumWalletCrypto` in XCode, run the following in a terminal and subsequently restart XCode:
```shell
/bin/launchctl setenv CONCORDIUM_WALLET_CRYPTO_PATH "../concordium-wallet-crypto-swift" # Or preferably an absolute path
``` 

and correspondingly to unset:
```shell
/bin/launchctl unsetenv CONCORDIUM_WALLET_CRYPTO_PATH
``` 

### Build and test SDK

With the Rust bindings in place, the SDK is built and tests executed using `swift test`.
It's not necessary to build the project in order to use it in other projects:
Just declare a dependency as explained in [usage](#usage).
The SDK will get compiled as part of the build process of the executable.

### Source code formatting

The source code is formatted according to the default rules of [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat).

The CI workflow [`Build and test`](https://github.com/Concordium/concordium-swift-sdk/blob/main/.github/workflows/build%2Btest.yml)
checks that the code base is correctly formatted before PRs are merged.

The formatter has been integrated as a
[Swift Package Manager plugin](https://github.com/nicklockwood/SwiftFormat#swift-package-manager-plugin).
It's possible to run the tool in a variety of ways (see the previous link for all options).
The easiest option is to run it on the command line via

```shell
make fmt
```

It may also be [invoked directly from XCode](https://github.com/nicklockwood/SwiftFormat#trigger-plugin-from-xcode)
by right-clicking on package root (i.e. `concordium-swift-sdk`) in the Project Navigator pane.
The tool is then listed under "SwiftFormat" as "SwiftFormatPlugin" in the context menu for formatting the entire project.

## Release new version

To ship a new release for version `<version>`, push a commit that inserts the version and release date 
to [`CHANGELOG.md`](./CHANGELOG.md), i.e., below `## [Unreleased]`, insert

```markdown
## [<version>] - <date>
```

Then simply push an *annotated* tag named `<version>` for this commit:

```shell
git tag -a <version>
```

Give the tag a message that explains briefly what changed.
This will trigger a [workflow](./.github/workflows/publish-release.yml) that publishes a GitHub release for the tag.
The release notes are constructed by concatenating the tag message with the changelog section 

Note that the GitHub release is really used only for presentation - the actual release is defined by the tag.
