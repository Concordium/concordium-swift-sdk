import Concordium // the SDK
import Foundation
import MnemonicSwift // external package for converting seed phrase to bytes

/// Construct seed from seed phrase.
public func decodeSeed(_ seedPhrase: String, _ network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return WalletSeed(seedHex: seedHex, network: network)
}

public func findIdentityProvider(_ endpoints: WalletProxyEndpoints, _ id: IdentityProviderID) async throws -> IdentityProviderJSON? {
    let res = try await endpoints.getIdentityProviders.response(session: URLSession.shared)
    return res.first { $0.ipInfo.ipIdentity == id }
}

public func issueIdentitySync(_ seed: WalletSeed, _ cryptoParams: CryptographicParameters, _ identityProvider: IdentityProvider, _ identityIndex: IdentityIndex, _ anonymityRevocationThreshold: RevocationThreshold, _ runIdentityProviderFlow: (_ issuanceStartURL: URL, _ requestJSON: String) throws -> URL) throws -> IdentityIssuanceRequest {
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

public func fetchIdentityIssuance(_ request: IdentityIssuanceRequest) async throws -> IdentityIssuanceResult {
    var delaySecs: UInt64 = 1
    while true {
        print("Attempting to fetch identity.")
        try await Task.sleep(nanoseconds: delaySecs * 1_000_000_000)
        let res = try await request.response(session: URLSession.shared).result
        if case let .pending(detail) = res {
            delaySecs = min(delaySecs * 2, 10) // exponential backoff
            var msg = ""
            if let detail, !detail.isEmpty {
                msg = " (\"\(detail)\")"
            }
            print("Verification pending\(msg). Retrying in \(delaySecs) s.")
            continue
        }
        return res
    }
}

public func prepareRecoverIdentity(
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
    return try urlBuilder.recoveryRequestToFetch(
        baseURL: identityProvider.metadata.recoveryStart,
        requestJSON: reqJSON
    )
}

/// Construct and sign transfer transaction.
public func makeTransfer(_ account: Account, _ amount: MicroCCDAmount, _ receiver: AccountAddress, _ seq: SequenceNumber, _ expiry: TransactionTime) throws -> SignedAccountTransaction {
    let tx = AccountTransaction(sender: account.address, payload: .transfer(amount: amount, receiver: receiver))
    return try account.keys.sign(transaction: tx, sequenceNumber: seq, expiry: expiry)
}
