import Common
import Concordium

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
// let expiry = TransactionTime(9_999_999_999)

// Run snippet within a context where a gRPC client has been made available.
try await withGRPCClient(target: .host("localhost", port: 20000)) { _ in
    let seed = try decodeSeed(seedPhrase, network)
    _ = seed
}
