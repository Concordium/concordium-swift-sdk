import Concordium // the SDK
import Foundation
import MnemonicSwift // external package for converting seed phrase to bytes

/// Construct seed from seed phrase.
public func decodeSeed(_ seedPhrase: String, _ network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return WalletSeed(seedHex: seedHex, network: network)
}

public func identityProviders(_ walletProxy: WalletProxy) async throws -> [IdentityProvider] {
    let res = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
    return res.map { $0.toSDKType() }
}

public func findIdentityProvider(_ walletProxy: WalletProxy, _ id: IdentityProviderID) async throws -> IdentityProvider? {
    let res = try await identityProviders(walletProxy)
    return res.first { $0.info.identity == id }
}

public func issueIdentitySync(
    _ seed: WalletSeed,
    _ cryptoParams: CryptographicParameters,
    _ identityProvider: IdentityProvider,
    _ identityIndex: IdentityIndex,
    _ anonymityRevocationThreshold: RevocationThreshold,
    _ runIdentityProviderFlow: (_ issuanceStartURL: URL, _ requestJSON: String) throws -> URL
) throws -> IdentityIssuanceRequest {
    print("Preparing identity issuance request.")
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    let reqJSON = try identityRequestBuilder.issuanceRequestJSON(
        provider: identityProvider,
        index: identityIndex,
        anonymityRevocationThreshold: anonymityRevocationThreshold
    )

    print("Start identity provider issuance flow.")
    let url = try runIdentityProviderFlow(identityProvider.metadata.issuanceStart, reqJSON)
    print("Identity verification process started!")
    return .init(url: url)
}

public func makeIdentityRecoveryRequest(
    _ seed: WalletSeed,
    _ cryptoParams: CryptographicParameters,
    _ identityProvider: IdentityProvider,
    _ identityIndex: IdentityIndex
) throws -> IdentityRecoverRequest {
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    let reqJSON = try identityRequestBuilder.recoveryRequestJSON(
        provider: identityProvider.info,
        index: identityIndex,
        time: Date.now
    )
    let urlBuilder = IdentityRequestURLBuilder(callbackURL: nil)
    return try urlBuilder.recoveryRequest(
        baseURL: identityProvider.metadata.recoveryStart,
        requestJSON: reqJSON
    )
}

/// Construct and sign transfer transaction.
public func makeTransfer(
    _ account: Account,
    _ amount: MicroCCDAmount,
    _ receiver: AccountAddress,
    _ seq: SequenceNumber,
    _ expiry: TransactionTime
) throws -> SignedAccountTransaction {
    let tx = AccountTransaction(sender: account.address, payload: .transfer(amount: amount, receiver: receiver))
    return try account.keys.sign(transaction: tx, sequenceNumber: seq, expiry: expiry)
}
