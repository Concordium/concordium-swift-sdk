import Concordium // the SDK
import Foundation
import MnemonicSwift // external package for converting seed phrase to bytes

/// Construct seed from seed phrase.
public func decodeSeed(_ seedPhrase: String, _ network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return try WalletSeed(seedHex: seedHex, network: network)
}

/// Fetch all identity providers.
public func identityProviders(_ walletProxy: WalletProxy) async throws -> [IdentityProvider] {
    let res = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
    return try res.map { try $0.toSDKType() }
}

/// Fetch an identity provider with a specific ID.
public func findIdentityProvider(_ walletProxy: WalletProxy, _ id: IdentityProviderID) async throws -> IdentityProvider? {
    let res = try await identityProviders(walletProxy)
    return res.first { $0.info.identity == id }
}
