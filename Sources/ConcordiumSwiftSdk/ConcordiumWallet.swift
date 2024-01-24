import Foundation

import ConcordiumWalletCrypto

enum ConcordiumNetwork: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

class ConcordiumWallet {
    let seedHex: String
    let network: ConcordiumNetwork

    init(seedHex: String, network: ConcordiumNetwork) {
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
