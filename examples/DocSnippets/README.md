# DocSnippets

Example snippets of code to be directly copied into documentation while being sure that they compile successfully.

The project is structured as a set of simple executable targets:

- [CreateIdentity](./Sources/CreateIdentity/main.swift) ([doc page](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk-identity-creation.html))
- [RecoverIdentity](./Sources/RecoverIdentity/main.swift) ([doc page](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk-identity-recovery.html))
- [CreateAccount](./Sources/CreateAccount/main.swift) ([doc page](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk-credential-deployment.html))
- [SignAndSendTransfer](./Sources/SignAndSendTransfer/main.swift) ([doc page](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk-account-transaction.html))
- [ListIdentityProviders](./Sources/ListIdentityProviders/main.swift) ([doc page](https://developer.concordium.software/en/mainnet/net/guides/wallet-sdk/wallet-sdk-identity-provider.html))

Except for `ListIdentityProviders`, the "main" code of each snippet is hosted in a function named `run`.
This function is executed by [`withGRPCClient`](./Sources/Common/GRPC.swift), which provides the `NodeClient` expected by `run`.

The library [Common](./Sources/Common) contains a set of small functions that are used by multiple snippets.
All the snippets share a dependency to this library.

## Build

Run `swift build` from this directory.

## Run

The snippets are meant purely for documenting how to use the SDK.
Even though they're organized as executables, they're not actually meant to be run - just compiled.

Some of the snippets do run while others have unimplemented "todo" parts that need to be provided by a hosting application.
Such commands (currently only `CreateIdentity`) will fail because they don't know how to, for example, open a web page.
Also, all inputs are hardcoded; no snippets accept any arguments.

Use the command `swift run <snippet>` to try running the snippet named `<snippet>` from the list above.

See the [CLI example](../CLI) for a "proper" tool with parameterized commands.
