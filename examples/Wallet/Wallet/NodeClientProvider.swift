import Concordium
import SwiftUI

// Configuration.
// Assumes that the app is run in an emulator and a Node is running locally.
// To use a remote node instead, forward traffic for the default target (localhost:20000) to <HOST>:<PORT>
// using the terminal command:
//
//   socat TCP-LISTEN:20000,fork TCP:<HOST>:<PORT>
let grpcHost = "localhost"
let grpcPort = 20000

struct NodeClientProvider<Content: View>: View {
    @State private var nodeClient: Result<DisposableNodeClient, Error>?

    var child: (DisposableNodeClient) -> Content

    var body: some View {
        VStack {
            switch nodeClient {
            case nil:
                Text("Starting NodeClient...")
            case let .failure(err):
                Text("Cannot start NodeClient: \(err.localizedDescription)")
            case let .success(n):
                child(n)
            }
        }
        .padding()
        .onAppear {
            do {
                nodeClient = try .success(DisposableNodeClient(target: .host(grpcHost, port: grpcPort)))
            } catch {
                nodeClient = .failure(error)
            }
        }.onDisappear {
            nodeClient = nil
        }
    }
}
