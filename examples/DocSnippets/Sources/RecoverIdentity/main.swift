import Common
import Concordium
import Foundation

// Inputs.
// TODO: Use inputs for which an identity actually exists
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let walletProxyBaseURL = URL(string: "https://wallet-proxy.testnet.concordium.com")!
let anonymityRevocationThreshold = RevocationThreshold(2)

// Run snippet within a context where a gRPC client has been made available.
try await withGRPCClient(target: .host("localhost", port: 20000)) { client in
    let seed = try decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxyEndpoints(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Construct recovery request.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try prepareRecoverIdentity(seed, cryptoParams, identityProvider.toSDKType(), identityIndex)

    // Execute request.
    let identity = try await identityReq.response(session: URLSession.shared)
    print("Successfully recovered identity: \(identity)")
}
