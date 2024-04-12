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
    let walletProxy = WalletProxyEndpoints(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Construct identity creation request and start verification.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try issueIdentitySync(seed, cryptoParams, identityProvider.toSDKType(), identityIndex, anonymityRevocationThreshold) { issuanceStartURL, requestJSON in
        // The URL to be invoked when once the ID verification process has started (i.e. once the data has been filled in).
        let callbackURL = URL(string: "concordiumwallet-example://identity-issuer/callback")!

        let urlBuilder = IdentityRequestURLBuilder(callbackURL: callbackURL)
        let url = try urlBuilder.issuanceURLToOpen(baseURL: issuanceStartURL, requestJSON: requestJSON)
        todoOpenURL(url)

        return todoAwaitCallbackWithVerificationPollingURL()
    }

    let res = try await todoFetchIdentityIssuance(identityReq)
    if case let .success(identity, _) = res {
        print("Identity issued successfully: \(identity))")
    } else {
        // Verification failed...
    }
}

func todoOpenURL(_: URL) {
    fatalError("'openURL' not implemented")
}

func todoAwaitCallbackWithVerificationPollingURL() -> URL {
    // Block the thread and wait for the callback URL to be invoked (and somehow capture that event).
    // In mobile wallets, the callback URL is probably a deep link that we listen on somewhere else.
    // In that case, this snippet would be done now and we would expect the handler to be eventually invoked.
    // In either case, the callback is how the IP hands over the verification polling URL.
    // As this is just for documentation, we simply return a dummy value here.
    fatalError("'awaitCallbackWithVerificationPollingURL' not implemented")
}

func todoFetchIdentityIssuance(_ request: IdentityIssuanceRequest) async throws -> IdentityIssuanceResult {
    // Block the thread, periodically polling for the verification ("identity issuance").
    // Return the result once it's no longer "pending".
    // In this example we just assume that it's non-pending right away.
    let res = try await request.response(session: URLSession.shared)
    return res.result
}

// Execute ``run`` within the context of a gRPC client.
try await withGRPCClient(target: .host("localhost", port: 20000), run)
