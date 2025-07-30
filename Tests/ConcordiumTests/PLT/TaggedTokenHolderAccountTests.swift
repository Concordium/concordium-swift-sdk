import XCTest
import Foundation
import SwiftCBOR
@testable import Concordium

final class TaggedTokenHolderAccountTests: XCTestCase {

    func testTaggedTokenHolderAccountSerialization() {
        let addressBytes = [UInt8](repeating: 0x15, count: 32)
        let account = PLT.TaggedTokenHolderAccount(data: addressBytes)

        let cbor = account.asCBOR().encode()
        let hex = Data(cbor).hexEncodedString()

        XCTAssertEqual(hex, "d99d73a10358201515151515151515151515151515151515151515151515151515151515151515")
    }
}

// MARK: - Helper

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
