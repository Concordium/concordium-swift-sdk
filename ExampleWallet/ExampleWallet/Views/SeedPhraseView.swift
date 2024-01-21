//import BitcoinKit
import SwiftUI
//import ConcordiumSwiftSDK


private let noSeedPhrase = ""

protocol SeedPhraseProvider {
    func saveSeedPhrase()
    func getSavedSeedPhrase() -> String
}

struct SeedPhraseView: View {
    @State private var seedPhrase: String = noSeedPhrase
    let seedPhraseKey = "seedPhrase"

    var body: some View {
        VStack {
            TextField("Enter seed phrase", text: $seedPhrase)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                saveSeedPhrase()
            }, label: {
                Text("Save seed phrase")
                    .foregroundColor(.white)
                    .padding()
                    .background(isValidSeedPhrase() ? Color.blue : Color.gray)
                    .cornerRadius(8)
            })
            .disabled(!isValidSeedPhrase())
            .padding()
        }.onAppear {
            seedPhrase = getSavedSeedPhrase()
        }
    }

    func isValidSeedPhrase() -> Bool {
        // TODO: Replace with a proper check
        !seedPhrase.isEmpty
    }
    /* BitcoinKit example
    func isValidSeedPhrase() -> Bool {
        do {
            // Attempt to create a mnemonic object from the given seed phrase
            let mnemonic = try Mnemonic(seed: seedPhrase)

            // Generate the seed from the mnemonic using BitcoinKit
            let seed = try Mnemonic.seed(mnemonic: mnemonic)

            // Use BitcoinKit to validate the seed
            let hdWallet = HDWallet(seed: seed, network: .mainnetBTC) // Adjust the network if needed
            let privateKey = try hdWallet.privateKey(index: 0)

            // If successful, the seed phrase is valid
            print("Valid Seed Phrase: \(mnemonic.words.joined(separator: " "))")
            return true
        } catch {
            // If an error occurs, the seed phrase is not valid
            print("Invalid Seed Phrase: \(error)")
            return false
        }
    }
     */
}

extension SeedPhraseView: SeedPhraseProvider {
    func saveSeedPhrase() {
        UserDefaults.standard.set(seedPhrase, forKey: seedPhraseKey)
    }

    func getSavedSeedPhrase() -> String {
        UserDefaults.standard.string(forKey: seedPhraseKey) ?? noSeedPhrase
    }
}

#Preview {
    SeedPhraseView()
}
