import Foundation

import ConcordiumWalletCrypto

enum ConcordiumNetwork: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

class ConcordiumHdWallet {
    let seedHex: String
    let network: ConcordiumNetwork

    init(seedHex: String, network: ConcordiumNetwork) {
        self.seedHex = seedHex
        self.network = network
    }

    func getAccountSigningKey(identityProviderIndex: UInt32, identityIndex: UInt32, credentialCounter: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex,
            credentialCounter: credentialCounter
        )
    }

    func getAccountPublicKey(identityProviderIndex: UInt32, identityIndex: UInt32, credentialCounter: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex,
            credentialCounter: credentialCounter
        )
    }

    func getCredentialId(identityProviderIndex: UInt32, identityIndex: UInt32, credentialCounter: UInt8, commitmentKey: String) throws -> String {
        try ConcordiumWalletCrypto.getCredentialId(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex,
            credentialCounter: credentialCounter,
            commitmentKey: commitmentKey
        )
    }

    func getPrfKey(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getPrfKey(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getIdCredSec(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getIdCredSec(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getSignatureBlindingRandomness(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getSignatureBlindingRandomness(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getAttributeCommitmentRandomness(identityProviderIndex: UInt32, identityIndex: UInt32, credentialCounter: UInt32, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.getAttributeCommitmentRandomness(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex,
            credentialCounter: credentialCounter,
            attribute: attribute
        )
    }

    func getVerifiableCredentialSigningKey(issuerIndex: UInt64, issuerSubindex: UInt64, verifiableCredentialIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialSigningKey(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: issuerIndex,
            issuerSubindex: issuerSubindex,
            verifiableCredentialIndex: verifiableCredentialIndex
        )
    }

    func getVerifiableCredentialPublicKey(issuerIndex: UInt64, issuerSubindex: UInt64, verifiableCredentialIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialPublicKey(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: issuerIndex,
            issuerSubindex: issuerSubindex,
            verifiableCredentialIndex: verifiableCredentialIndex
        )
    }

    func getVerifiableCredentialBackupEncryptionKey() throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialBackupEncryptionKey(
            seedHex: seedHex,
            network: network.rawValue
        )
    }
}
