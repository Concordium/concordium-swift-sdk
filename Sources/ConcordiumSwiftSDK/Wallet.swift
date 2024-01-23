import Foundation

import ConcordiumWalletCrypto

enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

class Wallet {
    let seedHex: String
    let network: Network

    init(seedHex: String, network: Network) {
        self.seedHex = seedHex
        self.network = network
    }

    func getAccountSigningKey(identityProviderIndex: UInt32, identityIndex: UInt32, credentialCounter: UInt32) throws -> String {
        let res = try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: seedHex,
            net: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex, credentialCounter: credentialCounter
        )
//        print(res)
        return res
    }
}
