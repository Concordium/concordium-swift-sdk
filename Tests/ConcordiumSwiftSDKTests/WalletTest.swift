@testable import ConcordiumSwiftSDK
import XCTest

final class WalletTest: XCTestCase {
    let someSeedHex = "877974c7dddda738dab2277073b218af3a3d84f2aa8c1245838cf49f93dddc9f3ee669e0a8a0f463cfde164bdc82208d97cb312d7777d37655575fe309a02934"

    func testTest() throws {
        let w = Wallet(seedHex: someSeedHex, network: .testnet)
        let res = try w.getAccountSigningKey(identityProviderIndex: 0, identityIndex: 0, credentialCounter: 0)
        print(res)
    }
}
