@testable import Concordium
import CryptoKit
import XCTest

final class WalletTest: XCTestCase {
    let TEST_SEED = "efa5e27326f8fa0902e647b52449bf335b7b605adc387015ec903f41d95080eb71361cbc7fb78721dcd4f3926a337340aa1406df83332c44c1cdcfe100603860"
    let TESTNET_CRYPTO_PARAMS = CryptographicParameters(
        onChainCommitmentKeyHex: "b14cbfe44a02c6b1f78711176d5f437295367aa4f2a8c2551ee10d25a03adc69d61a332a058971919dad7312e1fc94c5a8d45e64b6f917c540eee16c970c3d4b7f3caf48a7746284878e2ace21c82ea44bf84609834625be1f309988ac523fac",
        bulletproofGeneratorsHex: "", // not used in this test
        genesisString: "" // not used in this test
    )

    func testSimpleTransfer() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        let gen = SeedBasedAccountDerivation(seed: seed, cryptoParams: TESTNET_CRYPTO_PARAMS)
        let account1 = try gen.deriveAccount(
            credentials: [AccountCredentialSeedIndexes(identity: IdentitySeedIndexes(providerID: 0, index: 0), counter: 0)]
        )
        let account2 = try gen.deriveAccount(
            credentials: [AccountCredentialSeedIndexes(identity: IdentitySeedIndexes(providerID: 0, index: 0), counter: 1)]
        )

        // Construct transaction.
        let transaction = AccountTransaction(sender: account1.address, payload: .transfer(amount: 1_000_000, receiver: account2.address))
        let preparedTransaction = transaction.prepare(sequenceNumber: 0, expiry: 9_999_999_999, signatureCount: 1)

        // Serialize transaction and compute hash.
        let serializedTransaction = preparedTransaction.serialize()
        XCTAssertEqual(serializedTransaction.data.hex, "ee17ee6886c47df6f62b7dd34c24c5ee193f92f4a10671113210ccc938e80e43000000000000000000000000000001f50000002900000002540be3ff03c38725b05818ad8a23d120e4f362d5e90bf790bb502415a16f0d79cc51bc962200000000000f4240")
        let transactionHash = serializedTransaction.hash
        XCTAssertEqual(transactionHash.hex, "56cb3bbb655c2aae88406e14ff4e77bce01d6a921bf0628e25abbeb665255864")

        // Sign transaction hash and verify signature against public key of the credential used to generate account 1.
        let signatures = try account1.keys.sign(message: transactionHash)
        XCTAssertEqual(signatures.count, 1)
        let signaturesCred0 = signatures[0]!
        XCTAssertEqual(signaturesCred0.count, 1)
        let signature = signaturesCred0[0]!
        let account1PublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Data(
                hex: seed.publicKeyHex(
                    accountCredentialIndexes: AccountCredentialSeedIndexes(
                        identity: IdentitySeedIndexes(providerID: 0, index: 0),
                        counter: 0
                    )
                )
            )
        )
        XCTAssertTrue(account1PublicKey.isValidSignature(signature, for: transactionHash))
    }
}
