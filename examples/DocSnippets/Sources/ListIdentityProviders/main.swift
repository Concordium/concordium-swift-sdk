import Common
import Concordium
import Foundation

// Inputs.
let walletProxyBaseURL = URL(string: "https://wallet-proxy.testnet.concordium.com")!

let walletProxy = WalletProxyEndpoints(baseURL: walletProxyBaseURL)
print("Identity providers:")
for ip in try await identityProviders(walletProxy) {
    print("- \(ip.info.description.name)")
}
