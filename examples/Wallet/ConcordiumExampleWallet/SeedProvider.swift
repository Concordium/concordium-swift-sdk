import MnemonicSwift
import SwiftUI

struct SeedProvider<Content: View>: View {
    @State private var seedPhraseInput = ""
    @State private var seedHex: String?

    var content: (String) -> Content

    var body: some View {
        VStack {
            if let seedHex {
                content(seedHex)
            } else {
                Form {
                    Section(header: Text("Seed Phrase")) {
                        TextField("gospel bicycle...", text: $seedPhraseInput)
                            .onChange(of: seedPhraseInput) { _ in
                                do {
                                    seedHex = try Mnemonic.deterministicSeedString(from: seedPhraseInput)
                                } catch {
                                    seedHex = nil
                                }
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    SeedProvider { seedHex in
        Text("Seed (hex): \(seedHex)")
    }
}
