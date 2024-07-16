import Concordium
import Foundation
import MnemonicSwift

class SeedsViewModel: ObservableObject {
    @Published private var model: SeedsModel

    init(model: SeedsModel) {
        print("init!")
        self.model = model
    }

    var seedPhrases: [String] {
        model.seeds.map(\.seedPhrase)
    }

    func seedViewModel(seedPhrase: String) -> SeedViewModel {
        let seedModel = model.seeds.first { $0.seedPhrase == seedPhrase }
        return SeedViewModel(model: seedModel!)
    }

    func userEntered(seedPhrase: String) -> String {
        do {
            let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase.lowercased())
            model.seeds.append(SeedModel(seedHex: seedHex))
            return ""
        } catch {
            return seedPhrase
        }
    }
}

class SeedViewModel: ObservableObject {
    @Published private var model: SeedModel

    init(model: SeedModel) {
        self.model = model
    }

    var seedPhrase: String {
        model.seedPhrase
    }
}

class WalletViewModel: ObservableObject {
    @Published private var model: WalletModel

    init(model: WalletModel) {
        self.model = model
    }

    var identities: [SeedBasedIdentityObject] {
        []
    }
}
