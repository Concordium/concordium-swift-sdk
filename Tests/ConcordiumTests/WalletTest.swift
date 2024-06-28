@testable import Concordium
import CryptoKit
import NIO
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
            credentials: [.init(identity: .init(providerID: 0, index: 0), counter: 0)]
        )
        let account2 = try gen.deriveAccount(
            credentials: [.init(identity: .init(providerID: 0, index: 0), counter: 1)]
        )

        // Construct transaction.
        let transaction = AccountTransaction.transfer(sender: account1.address, receiver: account2.address, amount: 1_000_000)
        let preparedTransaction = transaction.prepare(sequenceNumber: 0, expiry: 9_999_999_999, signatureCount: 1)

        // Serialize transaction and compute hash.
        let serializedTransaction = preparedTransaction.serialize()
        XCTAssertEqual(serializedTransaction.data.hex, "ee17ee6886c47df6f62b7dd34c24c5ee193f92f4a10671113210ccc938e80e43000000000000000000000000000001f50000002900000002540be3ff03c38725b05818ad8a23d120e4f362d5e90bf790bb502415a16f0d79cc51bc962200000000000f4240")
        let transactionHash = serializedTransaction.hash
        XCTAssertEqual(transactionHash.hex, "56cb3bbb655c2aae88406e14ff4e77bce01d6a921bf0628e25abbeb665255864")

        // Sign transaction hash and verify signature against public key of the credential used to generate account 1.
        let signatures = try account1.keys.sign(transactionHash)
        XCTAssertEqual(signatures.count, 1)
        let signaturesCred0 = signatures[0]!
        XCTAssertEqual(signaturesCred0.count, 1)
        let signature = signaturesCred0[0]!
        let account1PublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Data(
                hex: seed.publicKeyHex(
                    accountCredentialIndexes: .init(
                        identity: .init(providerID: 0, index: 0),
                        counter: 0
                    )
                )
            )
        )
        XCTAssertTrue(account1PublicKey.isValidSignature(signature, for: transactionHash))
    }

    func testSignMessage() throws {
        let key = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(
                hex: "e5f7a2119681e469bd7f6bf832f2076efd307a3a6d284447e221267aac9a2ff2"
            )
        )
        let signer = AccountKeysCurve25519([0: [0: key]])
        let msg = "L".data(using: .ascii)!
        let address = try AccountAddress(base58Check: "3ovtzpkUSB9PrbH46FPogPY1GXJdPt2Z4QFj8m7shA1L57p6ek")
        let signatures = try signer.sign(message: msg, address: address)

        var buf = ByteBuffer()
        buf.writeData(address.data)
        buf.writeRepeatingByte(0, count: 8)
        buf.writeData(msg)
        let signedData = Data(buffer: buf)
        let signedHash = Data(SHA256.hash(data: signedData))

        // Verify that computed signature is valid.
        XCTAssertTrue(key.publicKey.isValidSignature(signatures[0]![0]!, for: signedHash))
        // Verify that we're signing the correct bytes by checking against signature computed externally.
        XCTAssertTrue(
            try key.publicKey.isValidSignature(
                Data(hex: "aa3e8b5ddc07f4a50d2e89f892a3db897a0acdd65cb4fc17519c905833a5c11bcb66142ad2216485a6bff746ea49e9f18ba7c668078f10f30c7716857606ab03"),
                for: signedHash
            )
        )
    }
}
