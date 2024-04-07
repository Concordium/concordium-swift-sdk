import SwiftUI

struct SeedView: View {
    @ObservedObject var viewModel: SeedViewModel

    var body: some View {
        Text(viewModel.seedPhrase)
    }
}

#Preview {
    SeedView(
        viewModel: SeedViewModel(
            model: SeedModel(seedHex: "efa5e27326f8fa0902e647b52449bf335b7b605adc387015ec903f41d95080eb71361cbc7fb78721dcd4f3926a337340aa1406df83332c44c1cdcfe100603860")
//            model: WalletModel(
//                seed: WalletSeed(
//                    seedHex: "", network: .testnet
//                ),
//                walletProxy: WalletProxyEndpoints(
//                    baseURL: URL(string: "http://example.com")!
//                ),
//                cryptoParams: CryptographicParameters(
//                    onChainCommitmentKeyHex: "",
//                    bulletproofGeneratorsHex: "",
//                    genesisString: ""
//                )
//            )
        )
    )
}
