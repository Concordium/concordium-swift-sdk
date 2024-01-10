import Foundation
@testable import ConcordiumSwiftSDK
import XCTest

class NonceTests: XCTestCase {

    func testInitialization() {
        let initialNonceValue: UInt = 42
        let nonce = Nonce(nonce: initialNonceValue)
        XCTAssertEqual(nonce.nonce, initialNonceValue, "Initialization should set the correct nonce value")
    }

    func testNext() {
        var nonce = Nonce(nonce: 42)
        let nextNonce = nonce.next()
        XCTAssertEqual(nextNonce.nonce, nonce.nonce + 1, "Next should return a new instance with an incremented nonce")
        XCTAssertEqual(nonce.nonce, 42, "Original instance should remain unchanged")
    }

    func testNextMut() {
        var nonce = Nonce(nonce: 42)
        nonce.nextMut()
        XCTAssertEqual(nonce.nonce, 43, "NextMut should increment the nonce in-place")
    }
}
