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

// Run snippet within a context where a gRPC client has been made available.
try await withGRPCClient(target: .host("localhost", port: 20000)) { client in
    let seed = try decodeSeed(seedPhrase, network)
    let cryptoParams = try await client.cryptographicParameters(block: BlockIdentifier.lastFinal)
    let walletProxy = WalletProxyEndpoints(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!
    let identityReq = try issueIdentitySync(seed, cryptoParams, identityProvider.toSDKType(), identityIndex, anonymityRevocationThreshold) { issuanceStartURL, requestJSON in
        // The URL to be invoked when once the ID verification process has started (i.e. once the data has been filled in).
        let callbackURL = URL(string: "concordiumwallet-example://identity-issuer/callback")!

        let urlBuilder = IdentityRequestURLBuilder(callbackURL: callbackURL)
        let url = try urlBuilder.issuanceURLToOpen(baseURL: issuanceStartURL, requestJSON: requestJSON)
        todoOpenURL(url)

        return todoAwaitCallbackWithVerificationPollingURL()
    }

    // Periodically poll verification status for as long as it's pending.
    let res = try await fetchIdentityIssuance(identityReq)
    if case let .success(identity, _) = res {
        print("Identity issued successfully: \(identity))")
    } else {
        // Verification failed...
    }
}

func todoOpenURL(_: URL) {
    fatalError("TODO: Need to implement method for opening the IP identification page in a web view.")
}

func todoAwaitCallbackWithVerificationPollingURL() -> URL {
    // Block the thread and wait for the callback URL to be invoked (and somehow capture that event).
    // In mobile wallets, the callback URL is probably a deep link that we listen on somewhere else.
    // In that case, this snippet would be done now and we would expect the handler to be eventually invoked.
    // In either case, the callback is how the IP hands over the verification polling URL.
    // As this is just for documentation, we simply return a dummy value here.
    URL(string: "http://example.com")!
}
