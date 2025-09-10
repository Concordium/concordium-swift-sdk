import XCTest
import Foundation
import SwiftCBOR
@testable import Concordium

final class CborMemoTests: XCTestCase {
    
    func testMemoTextStringSerialization() {
        let memo1 = PLT.CborMemo(string: "Hello world")!
        XCTAssertEqual(
            Data(memo1.asCBOR().encode()).hexEncodedString(),
            "d8184b48656c6c6f20776f726c64"
        )
        
        let memo2 = PLT.CborMemo(string: "My memo")!
        XCTAssertEqual(
            Data(memo2.asCBOR().encode()).hexEncodedString(),
            "d818474d79206d656d6f"
        )
        
        let russianText = "Неплохо сработано, мистер Раз-Два 👩🏻‍🔬"
        let memo3 = PLT.CborMemo(string: russianText)!
        XCTAssertEqual(
            Data(memo3.asCBOR().encode()).hexEncodedString(),
            "d818584dd09dd0b5d0bfd0bbd0bed185d0be20d181d180d0b0d0b1d0bed182d0b0d0bdd0be2c20d0bcd0b8d181d182d0b5d18020d0a0d0b0d0b72dd094d0b2d0b020f09f91a9f09f8fbbe2808df09f94ac"
        )
    }

    func testMemoTextSerialization() {
        let memo1 = PLT.CborMemo(cborObject: CBOR.utf8String("Hello world"))!
        XCTAssertEqual(
            Data(memo1.asCBOR().encode()).hexEncodedString(),
            "d8184c6b48656c6c6f20776f726c64"
        )

        let russianText = "Неплохо сработано, мистер Раз-Два 👩🏻‍🔬"
        let memo2 = PLT.CborMemo(cborObject: CBOR.utf8String(russianText))!
        XCTAssertEqual(
            Data(memo2.asCBOR().encode()).hexEncodedString(),
            "d818584f784dd09dd0b5d0bfd0bbd0bed185d0be20d181d180d0b0d0b1d0bed182d0b0d0bdd0be2c20d0bcd0b8d181d182d0b5d18020d0a0d0b0d0b72dd094d0b2d0b020f09f91a9f09f8fbbe2808df09f94ac"
        )
    }

    func testMemoRawSerialization() {
        let memo = PLT.CborMemo(rawCBOR: [1, 2, 3])!
        XCTAssertEqual(
            Data(memo.asCBOR().encode()).hexEncodedString(),
            "d81843010203"
        )
    }

    func testMemoNullSerialization() {
        let nullCBOR = CBOR.null
        let memo = PLT.CborMemo(cborObject: nullCBOR)!
        XCTAssertEqual(
            Data(memo.asCBOR().encode()).hexEncodedString(),
            "d81841f6"
        )
    }

    func testTooLongMemoFails() {
        let longData = Data(repeating: 0x00, count: 257)
        XCTAssertNil(PLT.CborMemo(data: longData))
    }
}

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
