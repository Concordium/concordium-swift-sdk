import MnemonicSwift
import SwiftUI

struct SeedsView: View {
    @ObservedObject var viewModel: SeedsViewModel
    @State private var seedPhraseInput: String = ""

    var body: some View {
        VStack {
            NavigationStack {
                List(viewModel.seedPhrases, id: \.self) { seedPhrase in
                    NavigationLink(
                        destination: SeedView(
                            viewModel: viewModel.seedViewModel(seedPhrase: seedPhrase)
                        )
                    ) {
                        Text(seedPhrase).lineLimit(1)
                    }
                }
            }
            Form {
                Section(header: Text("Add Seed Phrase")) {
                    TextField("gospel bicycle...", text: $seedPhraseInput)
                        .onChange(of: seedPhraseInput) { _ in
                            seedPhraseInput = viewModel.userEntered(seedPhrase: seedPhraseInput)
                        }
                }
            }
        }
    }
}

#Preview {
    SeedsView(
        viewModel: SeedsViewModel(
            model: SeedsModel(
                seeds: [
                    SeedModel(seedHex: "efa5e27326f8fa0902e647b52449bf335b7b605adc387015ec903f41d95080eb71361cbc7fb78721dcd4f3926a337340aa1406df83332c44c1cdcfe100603860"),
                ]
            )
        )
    )
}
