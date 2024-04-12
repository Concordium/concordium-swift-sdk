import Concordium // the SDK
import MnemonicSwift // external package for converting seed phrase to bytes

/// Construct seed from seed phrase.
public func decodeSeed(_ seedPhrase: String, _ network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return WalletSeed(seedHex: seedHex, network: network)
}

/// Derive seed based account from the given coordinates of a given seed.
public func deriveAccount(_ seed: WalletSeed, _ id: IdentityProviderID, _ idx: IdentityIndex, _ credCnt: CredentialCounter, _ cryptoParams: CryptographicParameters) throws -> Account {
    let accountDerivation = try SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
    return try accountDerivation.deriveAccount(
        credentials: [
            .init(
                identity: .init(providerID: id, index: idx),
                counter: credCnt
            ),
        ]
    )
}

/// Construct and sign transfer transaction.
public func makeTransfer(_ account: Account, _ amount: MicroCCDAmount, _ receiver: AccountAddress, _ seq: SequenceNumber, _ expiry: TransactionTime) throws -> SignedAccountTransaction {
    let tx = AccountTransaction(sender: account.address, payload: .transfer(amount: amount, receiver: receiver))
    return try account.keys.sign(transaction: tx, sequenceNumber: seq, expiry: expiry)
}
