import SwiftUI

@main
struct ExampleWalletApp: App {
    var body: some Scene {
        ClientManager.shared.initialize()

        WindowGroup {
            MainView()
        }
    }
}
