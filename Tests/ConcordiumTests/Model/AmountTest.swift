import BigInt
@testable import Concordium
import Foundation
import XCTest

final class AmountTest: XCTestCase {
    /// Helper function for conveniently using decimal separator ".".
    func amount(_ input: String, decimalCount: Int) throws -> Amount {
        try Amount(input, decimalCount: decimalCount, decimalSeparator: ".")
    }

    func testCannotParseNegativeDecimals() throws {
        XCTAssertThrowsError(try amount("0", decimalCount: -1)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.negativeDecimalCount)
        }
    }

    func testCannotParseEmpty() throws {
        XCTAssertThrowsError(try amount("", decimalCount: 0)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.invalidInput)
        }
    }

    func testCannotParseNonNumeric() throws {
        XCTAssertThrowsError(try amount("x", decimalCount: 1)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.invalidInput)
        }
    }

    func testCanParseNoDecimals() throws {
        XCTAssertEqual(try amount("0", decimalCount: 0), Amount(BigUInt(0), decimalCount: 0))
        XCTAssertEqual(try amount("00", decimalCount: 0), Amount(BigUInt(0), decimalCount: 0))
        XCTAssertEqual(try amount("12", decimalCount: 0), Amount(BigUInt(12), decimalCount: 0))
    }

    func testCanParseDecimalCountDecimals() throws {
        XCTAssertEqual(try amount("0.0", decimalCount: 1), Amount(BigUInt(0), decimalCount: 1))
        XCTAssertEqual(try amount("00.1", decimalCount: 1), Amount(BigUInt(1), decimalCount: 1))
        XCTAssertEqual(try amount("1.0", decimalCount: 1), Amount(BigUInt(10), decimalCount: 1))
        XCTAssertEqual(try amount("0.02", decimalCount: 2), Amount(BigUInt(2), decimalCount: 2))
        XCTAssertEqual(try amount("0.12", decimalCount: 2), Amount(BigUInt(12), decimalCount: 2))
        XCTAssertEqual(try amount("1.20", decimalCount: 2), Amount(BigUInt(120), decimalCount: 2))
    }

    func testCanParseEmptyWholePart() throws {
        XCTAssertEqual(try amount(".1", decimalCount: 1), Amount(BigUInt(1), decimalCount: 1))
        XCTAssertEqual(try amount(".01", decimalCount: 2), Amount(BigUInt(1), decimalCount: 2))
    }

    func testCannotParseEmptyFracPart() throws {
        XCTAssertThrowsError(try amount("1.", decimalCount: 1)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.trailingDecimalSeparator)
        }
        XCTAssertThrowsError(try amount(".", decimalCount: 1)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.trailingDecimalSeparator)
        }
    }

    func testCanParseFewerDecimalsThanDecimalCount() throws {
        XCTAssertEqual(try amount("1", decimalCount: 1), Amount(BigUInt(10), decimalCount: 1))
        XCTAssertEqual(try amount("0.1", decimalCount: 2), Amount(BigUInt(10), decimalCount: 2))
        XCTAssertEqual(try amount("0.10", decimalCount: 3), Amount(BigUInt(100), decimalCount: 3))
    }

    func testCannotParseMoreDecimalsThanDecimalCount() throws {
        XCTAssertThrowsError(try amount("0.0", decimalCount: 0)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.tooManyFractionalDigits)
        }
        XCTAssertThrowsError(try amount("1.23", decimalCount: 1)) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.tooManyFractionalDigits)
        }
    }

    func testCanParseManyZeros() throws {
        XCTAssertEqual(
            try amount("0000000000000000000000000000000000000000", decimalCount: 0),
            Amount(BigUInt(0), decimalCount: 0)
        )
        XCTAssertEqual(
            try amount("00000000000000000000.00000000000000000000", decimalCount: 20),
            Amount(BigUInt(0), decimalCount: 20)
        )
    }

    func testCanParseHugeNumber() throws {
        XCTAssertEqual(
            try amount("0123456789123456789001234567891234567890", decimalCount: 0),
            Amount(BigUInt("123456789123456789001234567891234567890"), decimalCount: 0)
        )
        XCTAssertEqual(
            try amount("012345678901234567890.0123456789123456789", decimalCount: 20),
            Amount(BigUInt("1234567890123456789001234567891234567890"), decimalCount: 20)
        )
        XCTAssertEqual(
            try amount("012345678901234567890012345678901234567890", decimalCount: 20),
            Amount(BigUInt("1234567890123456789001234567890123456789000000000000000000000"), decimalCount: 20)
        )
    }

    func testCanUseOtherDecimalSeparator() throws {
        XCTAssertEqual(try Amount("0@0", decimalCount: 1, decimalSeparator: "@"), Amount(BigUInt(0), decimalCount: 1))
        XCTAssertEqual(try Amount("1x2", decimalCount: 1, decimalSeparator: "x"), Amount(BigUInt(12), decimalCount: 1))
    }

    func testCannotParseDotWhenUsingOtherDecimalSeparator() throws {
        XCTAssertThrowsError(try Amount("2.1", decimalCount: 1, decimalSeparator: "!")) { err in
            XCTAssertEqual(err as! AmountParseError, AmountParseError.invalidInput)
        }
    }

    // TODO: Implement...
//    func testUsesDecimalSeparatorFromLocaleByDefault() throws {
//        var components = Locale.Components(languageCode: "da", languageRegion: "DK")
    ////        components.region = Locale.Region("S")
//        let da_DK = Locale(components: components)
//        UserDefaults.standard.set("da", forKey: "i18n_language")
//    }

    // TODO: Add tests for formatting
}
