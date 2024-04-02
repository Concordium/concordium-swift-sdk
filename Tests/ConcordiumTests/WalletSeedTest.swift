@testable import Concordium
import CryptoKit
import XCTest

final class WalletSeedTest: XCTestCase {
    let TEST_SEED = "efa5e27326f8fa0902e647b52449bf335b7b605adc387015ec903f41d95080eb71361cbc7fb78721dcd4f3926a337340aa1406df83332c44c1cdcfe100603860"

    func testMainnetIdentityCredSec() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.credSecHex(
                identityIndexes: IdentitySeedIndexes(providerID: 2, index: 115)
            ),
            "33b9d19b2496f59ed853eb93b9d374482d2e03dd0a12e7807929d6ee54781bb1"
        )
    }

    func testMainnetIdentityPrfKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.prfKeyHex(
                identityIndexes: IdentitySeedIndexes(providerID: 3, index: 35)
            ),
            "4409e2e4acffeae641456b5f7406ecf3e1e8bd3472e2df67a9f1e8574f211bc5"
        )
    }

    func testMainnetIdentitySignatureBlindingRandomness() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.signatureBlindingRandomnessHex(
                identityIndexes: IdentitySeedIndexes(providerID: 4, index: 5713)
            ),
            "1e3633af2b1dbe5600becfea0324bae1f4fa29f90bdf419f6fba1ff520cb3167"
        )
    }

    func testMainnetAccountCredentialSigningKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.signingKeyHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 0, index: 55),
                    counter: 7
                )
            ),
            "e4d1693c86eb9438feb9cbc3d561fbd9299e3a8b3a676eb2483b135f8dbf6eb1"
        )
    }

    func testMainnetAccountCredentialPublicKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.publicKeyHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 1, index: 341),
                    counter: 9
                )
            ),
            "d54aab7218fc683cbd4d822f7c2b4e7406c41ae08913012fab0fa992fa008e98"
        )
    }

    func testMainnetAccountCredentialPublicAndSigningKeyMatch() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        let privateKey = try seed.signingKeyHex(
            accountCredentialIndexes: AccountCredentialSeedIndexes(
                identity: IdentitySeedIndexes(providerID: 0, index: 0),
                counter: 0
            )
        )
        let publicKey = try seed.publicKeyHex(
            accountCredentialIndexes: AccountCredentialSeedIndexes(
                identity: IdentitySeedIndexes(providerID: 0, index: 0),
                counter: 0
            )
        )
        let message = "abcd1234abcd5678".data(using: .ascii)!
        let signature = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(hex: privateKey)
        ).signature(for: message)
        XCTAssertTrue(
            try Curve25519.Signing.PublicKey(rawRepresentation: Data(hex: publicKey))
                .isValidSignature(signature, for: message)
        )
    }

    func testMainnetAccountCredentialId() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.idHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 10, index: 50),
                    counter: 5
                ),
                commitmentKey: "b14cbfe44a02c6b1f78711176d5f437295367aa4f2a8c2551ee10d25a03adc69d61a332a058971919dad7312e1fc94c5a8d45e64b6f917c540eee16c970c3d4b7f3caf48a7746284878e2ace21c82ea44bf84609834625be1f309988ac523fac"
            ),
            "8a3a87f3f38a7a507d1e85dc02a92b8bcaa859f5cf56accb3c1bc7c40e1789b4933875a38dd4c0646ca3e940a02c42d8"
        )
    }

    func testMainnetAccountCredentialAttributeCommitmentRandomness() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.attributeCommitmentRandomnessHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 5, index: 0),
                    counter: 4
                ),
                attribute: 0
            ),
            "6ef6ba6490fa37cd517d2b89a12b77edf756f89df5e6f5597440630cd4580b8f"
        )
    }

    func testTestnetIdentityCredSec() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.credSecHex(
                identityIndexes: IdentitySeedIndexes(providerID: 2, index: 115)
            ),
            "33c9c538e362c5ac836afc08210f4b5d881ba65a0a45b7e353586dad0a0f56df"
        )
    }

    func testTestnetIdentityPrfKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.prfKeyHex(
                identityIndexes: IdentitySeedIndexes(providerID: 3, index: 35)
            ),
            "41d794d0b06a7a31fb79bb76c44e6b87c63e78f9afe8a772fc64d20f3d9e8e82"
        )
    }

    func testTestnetIdentitySignatureBlindingRandomness() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.signatureBlindingRandomnessHex(
                identityIndexes: IdentitySeedIndexes(providerID: 4, index: 5713)
            ),
            "079eb7fe4a2e89007f411ede031543bd7f687d50341a5596e015c9f2f4c1f39b"
        )
    }

    func testTestnetAccountCredentialSigningKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.signingKeyHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 0, index: 55),
                    counter: 7
                )
            ),
            "aff97882c6df085e91ae2695a32d39dccb8f4b8d68d2f0db9637c3a95f845e3c"
        )
    }

    func testTestnetAccountCredentialPublicKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.publicKeyHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 1, index: 341),
                    counter: 9
                )
            ),
            "ef6fd561ca0291a57cdfee896245db9803a86da74c9a6c1bf0252b18f8033003"
        )
    }

    func testTestnetAccountCredentialPublicAndSigningKeyMatch() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        let privateKey = try seed.signingKeyHex(
            accountCredentialIndexes: AccountCredentialSeedIndexes(
                identity: IdentitySeedIndexes(providerID: 0, index: 0),
                counter: 0
            )
        )
        let publicKey = try seed.publicKeyHex(
            accountCredentialIndexes: AccountCredentialSeedIndexes(
                identity: IdentitySeedIndexes(providerID: 0, index: 0),
                counter: 0
            )
        )
        let message = "abcd1234abcd5678".data(using: .ascii)!
        let signature = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(hex: privateKey)
        ).signature(for: message)
        XCTAssertTrue(
            try Curve25519.Signing.PublicKey(rawRepresentation: Data(hex: publicKey))
                .isValidSignature(signature, for: message)
        )
    }

    func testTestnetAccountCredentialId() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.idHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 10, index: 50),
                    counter: 5
                ),
                commitmentKey: "b14cbfe44a02c6b1f78711176d5f437295367aa4f2a8c2551ee10d25a03adc69d61a332a058971919dad7312e1fc94c5a8d45e64b6f917c540eee16c970c3d4b7f3caf48a7746284878e2ace21c82ea44bf84609834625be1f309988ac523fac"
            ),
            "9535e4f2f964c955c1dd0f312f2edcbf4c7d036fe3052372a9ad949ff061b9b7ed6b00f93bc0713e381a93a43715206c"
        )
    }

    func testTestnetAttributeCommitmentRandomness() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.attributeCommitmentRandomnessHex(
                accountCredentialIndexes: AccountCredentialSeedIndexes(
                    identity: IdentitySeedIndexes(providerID: 5, index: 0),
                    counter: 4
                ),
                attribute: 0
            ),
            "409fa90314ec8fb4a2ae812fd77fe58bfac81765cad3990478ff7a73ba6d88ae"
        )
    }

    func testMainnetVerifiableCredentialSigningKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.signingKeyHex(
                verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(
                    issuer: IssuerSeedIndexes(index: 1, subindex: 2),
                    index: 1
                )
            ),
            "670d904509ce09372deb784e702d4951d4e24437ad3879188d71ae6db51f3301"
        )
    }

    func testMainnetVerifiableCredentialPublicKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .mainnet)
        XCTAssertEqual(
            try seed.publicKeyHex(
                verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(
                    issuer: IssuerSeedIndexes(index: 3, subindex: 1232),
                    index: 341
                )
            ),
            "16afdb3cb3568b5ad8f9a0fa3c741b065642de8c53e58f7920bf449e63ff2bf9"
        )
    }

    func testTestnetVerifiableCredentialSigningKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.signingKeyHex(
                verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(
                    issuer: IssuerSeedIndexes(index: 13, subindex: 0),
                    index: 1
                )
            ),
            "c75a161b97a1e204d9f31202308958e541e14f0b14903bd220df883bd06702bb"
        )
    }

    func testTestnetVerifiableCredentialPublicKey() throws {
        let seed = WalletSeed(seedHex: TEST_SEED, network: .testnet)
        XCTAssertEqual(
            try seed.publicKeyHex(
                verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(
                    issuer: IssuerSeedIndexes(index: 17, subindex: 0),
                    index: 341
                )
            ),
            "c52a30475bac88da9e65471cf9cf59f99dcce22ce31de580b3066597746b394a"
        )
    }
}
