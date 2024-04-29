import Common
import Concordium
import Foundation

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let walletProxyBaseURL = URL(string: "https://wallet-proxy.testnet.concordium.com")!
let anonymityRevocationThreshold = RevocationThreshold(2)

/// Perform identity recovery based on the inputs above.
func recoverIdentity(client: NodeClient) async throws {
    let seed = try decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxy(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Construct recovery request.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, identityIndex)

    // Execute request.
    let identityRes = try await identityReq.send(session: URLSession.shared)
    switch identityRes.result {
    case let .failure(err):
        print("Identity recovery failed: \(err)")
    case let .success(identity):
        print("Identity recovered successfully:")
        print(identity)
    }
}

// Duplicated in 'CreateAccount/main.swift'.
func makeIdentityRecoveryRequest(
    _ seed: WalletSeed,
    _ cryptoParams: CryptographicParameters,
    _ identityProvider: IdentityProvider,
    _ identityIndex: IdentityIndex
) throws -> IdentityRecoveryRequest {
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

// Execute ``recoverIdentity`` within the context of a gRPC client.
try await withGRPCClient(host: "localhost", port: 20000, recoverIdentity)
