import Concordium
import Foundation
import MnemonicSwift

class SeedsModel {
    var seeds: [SeedModel]

    init(seeds: [SeedModel] = []) {
        self.seeds = seeds
    }
}

class SeedModel {
    let seedHex: String
    var mainnet: WalletModel?
    var testnet: WalletModel?

    init(seedHex: String, mainnet: WalletModel? = nil, testnet: WalletModel? = nil) {
        self.seedHex = seedHex
        self.mainnet = mainnet
        self.testnet = testnet
    }

    var seedPhrase: String {
        do {
            return try Mnemonic.mnemonicString(from: seedHex)
        } catch {
            return error.localizedDescription
        }
    }
}

class WalletModel {
    private static let identityIssuanceCallbackURL = URL(string: "concordiumexamplewallet://identity-issuer/callback")!

    let accounts: AccountStore = .init()
    let wallet: Wallet

    init(seed: WalletSeed, walletProxy: WalletProxy, cryptoParams: CryptographicParameters) {
        wallet = Wallet(
            seed: seed,
            walletProxy: walletProxy,
            cryptoParams: cryptoParams,
            accounts: accounts,
            identityIssuanceCallbackURL: Self.identityIssuanceCallbackURL
        )
    }
}
