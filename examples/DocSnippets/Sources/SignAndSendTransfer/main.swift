import Common
import Concordium

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let network = Network.testnet
let identityProviderID = IdentityProviderID(3)
let identityIndex = IdentityIndex(7)
let credentialCounter = CredentialCounter(21)
let amount = CCD(microCCD: 1337)
let receiver = try! AccountAddress(base58Check: "33Po4Z5v4DaAHo9Gz9Afc9LRzbZmYikus4Q7gqMaXHtdS17khz")
let expiry = TransactionTime(9_999_999_999)

/// Perform a transfer based on the inputs above.
func transfer(client: NodeClient) async throws {
    let seed = try decodeSeed(seedPhrase, network)

    // Derive seed based account from the given coordinates of the given seed.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
    let credentialIndexes = AccountCredentialSeedIndexes(
        identity: .init(providerID: identityProviderID, index: identityIndex),
        counter: credentialCounter
    )
    let account = try accountDerivation.deriveAccount(credentials: [credentialIndexes])

    // Construct, sign, and send transfer transaction.
    let nextSeq = try await client.nextAccountSequenceNumber(address: account.address)
    let signed = try makeTransfer(account, amount, receiver, nextSeq.sequenceNumber, expiry)
    let submitted = try await client.send(transaction: signed)
    print("Transaction with hash '\(submitted.hash.hex)' successfully submitted.")
}

/// Construct and sign transfer transaction.
func makeTransfer(
    _ account: Account,
    _ amount: CCD,
    _ receiver: AccountAddress,
    _ seq: SequenceNumber,
    _ expiry: TransactionTime
) throws -> SignedAccountTransaction {
    let tx = AccountTransaction.transfer(sender: account.address, receiver: receiver, amount: amount)
    return try account.keys.sign(transaction: tx, sequenceNumber: seq, expiry: expiry)
}

// Execute ``transfer`` within the context of a gRPC client.
try await withGRPCClient(host: "localhost", port: 20000, transfer)
