import BigInt
@testable import Concordium
import Foundation
import SwiftCBOR
import XCTest

final class TokenOperationAmountTests: XCTestCase {
    func testTokenOperationAmountSerialization() {
        // Test 1500000 with 6 decimals -> exponent = -6, value = 1500000
        let amount1 = PLT.TokenOperationAmount(value: BigUInt(1_500_000), decimals: 6)
        XCTAssertEqual(
            Data(amount1.asCBOR().encode()).hexEncodedString(),
            "c482251a0016e360"
        )

        // Test 1234567 with 3 decimals -> exponent = -3
        let amount2 = PLT.TokenOperationAmount(value: BigUInt(1_234_567), decimals: 3)
        XCTAssertEqual(
            Data(amount2.asCBOR().encode()).hexEncodedString(),
            "c482221a0012d687"
        )

        // Test Long.MIN_VALUE (2^63) with 3 decimals
        let minLong = BigUInt(1) << 63
        let amount3 = PLT.TokenOperationAmount(value: minLong, decimals: 3)
        XCTAssertEqual(
            Data(amount3.asCBOR().encode()).hexEncodedString(),
            "c482221b8000000000000000"
        )

        // Test Long.MAX_VALUE (2^63 - 1) with 3 decimals
        let maxLong = BigUInt(1) << 63 - 1
        let amount4 = PLT.TokenOperationAmount(value: maxLong, decimals: 3)
        XCTAssertEqual(
            Data(amount4.asCBOR().encode()).hexEncodedString(),
            "c482221b7fffffffffffffff"
        )

        // Test -1 encoded as BigUInt (in BigUInt there is no -1 so just max)
        // Simulate by providing UInt64.max
        let amount5 = PLT.TokenOperationAmount(value: BigUInt(UInt64.max), decimals: 3)
        XCTAssertEqual(
            Data(amount5.asCBOR().encode()).hexEncodedString(),
            "c482221bffffffffffffffff"
        )
    }
}

// MARK: - Helper

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
