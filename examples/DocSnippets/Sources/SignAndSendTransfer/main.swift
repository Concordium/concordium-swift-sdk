import Common
import Concordium

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let credentialCounter = CredentialCounter(21)
let amount = MicroCCDAmount(1337)
let receiver = try! AccountAddress(base58Check: "33Po4Z5v4DaAHo9Gz9Afc9LRzbZmYikus4Q7gqMaXHtdS17khz")
let expiry = TransactionTime(9_999_999_999)

// Run snippet within a context where a gRPC client has been made available.
try await withGRPCClient(target: .host("localhost", port: 20000)) { client in
    let seed = try decodeSeed(seedPhrase, network)
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let account = try deriveAccount(seed, identityProviderID, identityIndex, credentialCounter, cryptoParams)
    let nextSeq = try await client.nextAccountSequenceNumber(address: account.address)
    let tx = try makeTransfer(account, amount, receiver, nextSeq.sequenceNumber, expiry)
    let hash = try await client.send(transaction: tx)
    print("Transaction with hash '\(hash.hex)' successfully submitted.")
}
