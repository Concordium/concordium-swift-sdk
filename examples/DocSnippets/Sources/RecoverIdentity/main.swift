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

func run(client: NodeClient) async throws {
    let seed = try decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxy(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Construct recovery request.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, identityIndex)

    // Execute request.
    let identity = try await identityReq.send(session: URLSession.shared)
    print("Successfully recovered identity: \(identity)")
}

// Execute ``run`` within the context of a gRPC client.
try await withGRPCClient(target: .host("localhost", port: 20000), run)
