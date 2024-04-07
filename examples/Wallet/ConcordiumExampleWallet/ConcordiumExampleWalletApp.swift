import SwiftUI

@main
struct ConcordiumExampleWalletApp: App {
    @StateObject private var viewModel = SeedsViewModel(model: SeedsModel())

    var body: some Scene {
        WindowGroup {
            SeedsView(viewModel: viewModel)
        }
    }
}
