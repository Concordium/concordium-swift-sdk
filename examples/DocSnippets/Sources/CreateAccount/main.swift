import Common
import Concordium
import Foundation

// Inputs.
// TODO: Use inputs for which an identity actually exists
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let credentialCounter = CredentialCounter(21)
let walletProxyBaseURL = URL(string: "https://wallet-proxy.testnet.concordium.com")!
let anonymityRevocationThreshold = RevocationThreshold(2)
let expiry = TransactionTime(9_999_999_999)

// Run snippet within a context where a gRPC client has been made available.
try await withGRPCClient(target: .host("localhost", port: 20000)) { client in
    let seed = try decodeSeed(seedPhrase, network)
    let walletProxy = WalletProxyEndpoints(baseURL: walletProxyBaseURL)
    let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

    // Recover identity (not necessary if the ID is already stored).
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let identityReq = try prepareRecoverIdentity(seed, cryptoParams, identityProvider.toSDKType(), identityIndex)
    let identity = try await identityReq.response(session: URLSession.shared)

    // Derive seed based credential and account from the given coordinates of a given seed.
    let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
    let seedIndexes = AccountCredentialSeedIndexes(
        identity: .init(providerID: identityProviderID, index: identityIndex),
        counter: credentialCounter
    )
    // Credential to deploy.
    let credential = try accountDerivation.deriveCredential(
        seedIndexes: seedIndexes,
        identity: identity.value,
        provider: identityProvider.toSDKType(),
        threshold: 1
    )
    // Account used to sign the deployment.
    // The account is composed from just the credential derived above,
    // but only the public key was derived in that call.
    // This one derives the credential's signing key.
    let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])

    let signedTx = try account.keys.sign(deployment: credential, expiry: expiry)
    let serializedTx = try signedTx.serialize()

    let hash = try await client.send(deployment: serializedTx)
    print("Transaction with hash '\(hash.hex)' successfully submitted.")
}
