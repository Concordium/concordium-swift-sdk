import SwiftUI

@main
struct WalletApp: App {
    var body: some Scene {
        WindowGroup {
            NodeClientProvider(
                child: {
                    AccountDetailsView(
                        nodeClient: $0,
                        address: "33Po4Z5v4DaAHo9Gz9Afc9LRzbZmYikus4Q7gqMaXHtdS17khz"
                    )
                }
            )
        }
    }
}
