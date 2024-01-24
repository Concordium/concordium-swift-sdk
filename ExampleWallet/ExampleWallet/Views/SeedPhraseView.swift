import SwiftUI

private let noSeedPhrase = ""

protocol SeedPhraseProvider {
    func saveSeedPhrase()
    func getSavedSeedPhrase() -> String
}

struct SeedPhraseView: View {
    @State private var seedPhrase: String = noSeedPhrase
    let seedPhraseValidator: SeedPhraseValidator = RealSeedPhraseValidator()

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

    // Example of valid seed phrase:
    // "flash tobacco obey genius army stove desk anchor quarter reflect chalk caution"
    func isValidSeedPhrase() -> Bool {
        seedPhraseValidator.isValid(seedPhrase: seedPhrase)
    }
}

extension SeedPhraseView: SeedPhraseProvider {
    var seedPhraseKey: String { "seedPhrase" }

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
