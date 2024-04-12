import Concordium // the SDK
import MnemonicSwift // external package for converting seed phrase to bytes

/// Construct seed from seed phrase.
func decodeSeed(seedPhrase: String, network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return WalletSeed(seedHex: seedHex, network: network)
}

func deriveAccount(cryptoParams: CryptographicParameters) throws -> Account {
    let accountDerivation = try SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
    return accountDerivation.deriveAccount(
        credentials: [
            .init(
                identity: .init(providerID: identityProviderID, index: identityIndex),
                counter: credentialCounter
            ),
        ]
    )
}

/// Construct and sign transaction.
func makeTransfer(account: Account, amount: MicroCCDAmount, receiver: AccountAddress, nextSeq: NextAccountSequenceNumber, expiry: TransactionTime) -> SignedAccountTransaction {
    let tx = AccountTransaction(sender: account.address, payload: .transfer(amount: amount, receiver: receiver))
    return account.keys.sign(tx, sequenceNumber: nextSeq, expiry: expiry)
}
