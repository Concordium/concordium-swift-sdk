import Concordium
import Foundation
import SwiftUI

struct AccountDetailsView: View {
    var nodeClient: DisposableNodeClient
    var address: String

    @State private var info: Result<AccountInfo, Error>?

    var body: some View {
        ScrollView {
            switch info {
            case nil:
                Text("Loading info for account '\(address)'...")
            case let .failure(err):
                Text("Cannot load account info: \(err.localizedDescription)")
            case let .success(info):
                Text("\(String(reflecting: info))")
            }
        }.task {
            do {
                let res = try await nodeClient.client.info(
                    account: .address(.init(base58Check: address)),
                    block: .lastFinal
                )
                info = .success(res)
            } catch {
                info = .failure(error)
            }
        }
    }
}
