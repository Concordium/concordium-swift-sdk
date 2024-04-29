import Common
import Concordium
import Foundation

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let credentialCounter = CredentialCounter(21)
let walletProxyBaseURL = URL(string: "https://wallet-proxy.testnet.concordium.com")!
let expiry = TransactionTime(9_999_999_999)

/// Perform account creation (on recovered identity) based on the inputs above.
func createAccount(client: NodeClient) async throws {
    let seed = try decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxy(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Recover identity (skip if the ID is already available).
    // This assumes that the identity already exists, of course.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, identityIndex)
    let identityRes = try await identityReq.send(session: URLSession.shared)

    // We assume that the identity already exists. Real applications should handle errors better.
    let identity = try identityRes.result.get()

    // Derive seed based credential and account from the given coordinates of the given seed.
    let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
    let seedIndexes = AccountCredentialSeedIndexes(
        identity: .init(providerID: identityProviderID, index: identityIndex),
        counter: credentialCounter
    )
    // Credential to deploy.
    let credential = try accountDerivation.deriveCredential(
        seedIndexes: seedIndexes,
        identity: identity.value,
        provider: identityProvider,
        threshold: 1
    )
    // Account used to sign the deployment.
    // The account is composed from just the credential derived above.
    // From this call the credential's signing key will be derived;
    // in the previous only the public key was.
    let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])

    // Construct, sign, and send deployment transaction.
    let signedTx = try account.keys.sign(deployment: credential, expiry: expiry)
    let serializedTx = try signedTx.serialize()
    let hash = try await client.send(deployment: serializedTx)
    print("Transaction with hash '\(hash.hex)' successfully submitted.")
}

// Duplicated in 'RecoverIdentity/main.swift'.
// TODO: Figure out how to depend on 'RecoverIdentity' and use its impl (got it to compile but linking failed).
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

// Execute ``createAccount`` within the context of a gRPC client.
try await withGRPCClient(host: "localhost", port: 20000, createAccount)
