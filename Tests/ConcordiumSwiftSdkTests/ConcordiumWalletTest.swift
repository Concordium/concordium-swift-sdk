@testable import ConcordiumSwiftSdk
import CryptoKit
import XCTest

final class ConcordiumWalletTest: XCTestCase {
    let TEST_SEED = "efa5e27326f8fa0902e647b52449bf335b7b605adc387015ec903f41d95080eb71361cbc7fb78721dcd4f3926a337340aa1406df83332c44c1cdcfe100603860"
    let TESTNET_COMMITMENT_KEY = "b14cbfe44a02c6b1f78711176d5f437295367aa4f2a8c2551ee10d25a03adc69d61a332a058971919dad7312e1fc94c5a8d45e64b6f917c540eee16c970c3d4b7f3caf48a7746284878e2ace21c82ea44bf84609834625be1f309988ac523fac"

    func testSimpleTransfer() throws {
        let seed = ConcordiumWalletSeed(hex: TEST_SEED, network: .testnet)
        let wallet = ConcordiumHdWallet(seed: seed)
        let account1 = try wallet.generateAccount(
            credentials: [ConcordiumCredential(identityProviderIndex: 0, identityIndex: 0, credentialCounter: 0)],
            commitmentKey: TESTNET_COMMITMENT_KEY
        )
        let account2 = try wallet.generateAccount(
            credentials: [ConcordiumCredential(identityProviderIndex: 0, identityIndex: 0, credentialCounter: 1)],
            commitmentKey: TESTNET_COMMITMENT_KEY
        )

        let transaction = AccountTransaction.simpleTransfer(
            from: account1,
            to: account2.address,
            amount: 1_000_000,
            sequenceNumber: 0,
            expiry: 9_999_999_999
        )
        let serialized = try transaction.serialize()
        XCTAssertEqual(serialized.data.hex, "ee17ee6886c47df6f62b7dd34c24c5ee193f92f4a10671113210ccc938e80e43000000000000000000000000000001f50000002900000002540be3ff03c38725b05818ad8a23d120e4f362d5e90bf790bb502415a16f0d79cc51bc962200000000000f4240")

        // TODO: Verify hash.

        let signatures = try wallet.sign(serialized.hash, with: account1)

        XCTAssertEqual(signatures.count, 1)
        let signaturesCred0 = signatures[0]!
        XCTAssertEqual(signaturesCred0.count, 1)
        let signature = signaturesCred0[0]!

        // Verify signature against public key of first (and only) credential on account 1.
        let account1PublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Data(
                hex: wallet.seed.getPublicKey(of: account1.credentials[0])
            )
        )
        XCTAssertTrue(account1PublicKey.isValidSignature(signature, for: serialized.hash))
    }
}
