import Foundation
import MnemonicSwift

protocol SeedPhraseValidator {
    func isValid(seedPhrase: String) -> Bool
}

struct RealSeedPhraseValidator: SeedPhraseValidator {
    func isValid(seedPhrase: String) -> Bool {
        do {
            try Mnemonic.validate(mnemonic: seedPhrase)
            return true
        } catch {
            return false
        }
    }
}
