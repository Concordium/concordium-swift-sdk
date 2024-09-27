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

/// Perform an identity creation based on the inputs above.
func createIdentity(client: NodeClient) async throws {
    let seed = try await decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxy(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Construct identity creation request and start verification.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
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
    let statusURL = try issueIdentitySync(reqJSON, identityProvider) { issuanceStartURL, requestJSON in
        // The URL to be invoked when once the ID verification process has started (i.e. once the data has been filled in).
        let callbackURL = URL(string: "concordiumwallet-example://identity-issuer/callback")!

        let urlBuilder = IdentityRequestURLBuilder(callbackURL: callbackURL)
        let url = try urlBuilder.issuanceURLToOpen(baseURL: issuanceStartURL, requestJSON: requestJSON)
        todoOpenURL(url)

        return todoAwaitCallbackWithVerificationPollingURL()
    }

    let res = try await todoAwaitVerification(statusURL)
    if case let .success(identity) = res {
        print("Identity issued successfully: \(identity))")
    } else {
        // Verification failed...
    }
}

func issueIdentitySync(
    _ issuanceRequestJSON: String,
    _ identityProvider: IdentityProvider,
    _ runIdentityProviderFlow: (_ issuanceStartURL: URL, _ requestJSON: String) throws -> URL
) throws -> IdentityVerificationStatusRequest {
    print("Start identity provider issuance flow.")
    let url = try runIdentityProviderFlow(identityProvider.metadata.issuanceStart, issuanceRequestJSON)
    print("Identity verification process started!")
    return .init(url: url)
}

func todoOpenURL(_: URL) {
    // Open the URL in a web view to start the identity verification flow with the identity provider.
    fatalError("'openURL' not implemented")
}

func todoAwaitCallbackWithVerificationPollingURL() -> URL {
    // Block the thread and wait for the callback URL to be invoked (and somehow capture that event).
    // In mobile wallets, the callback URL is probably a deep link that we listen on somewhere else.
    // In that case, this snippet would be done now and we would expect the handler to be eventually invoked.
    // In either case, the callback is how the IP hands over the URL for polling the verification status -
    // and for some reason it does so in the *fragment* part of the URL!
    // See 'server.swift' of the example CLI for a server-based solution that works in a synchronous context.
    // Warning: It ain't pretty.
    fatalError("'awaitCallbackWithVerificationPollingURL' not implemented")
}

func todoAwaitVerification(_ request: IdentityVerificationStatusRequest) async throws -> IdentityVerificationResult {
    // Dummy impl that simply blocks the thread and periodically polls the verification status.
    while true {
        let status = try await request.send(session: URLSession.shared)
        if let r = status.result {
            // Status is no longer "pending"; return the result.
            return r
        }
        try await Task.sleep(nanoseconds: 10 * 1_000_000_000) // check once every 10s
    }
}

// Execute ``createIdentity`` within the context of a gRPC client.
try await withGRPCClient(host: "localhost", port: 20000, createIdentity)
