import Base58Check
@testable import ConcordiumSwiftSDK
import Foundation
import XCTest

final class AddressTest: XCTestCase {

    func testCanParseValidAddressString() async throws {
        let a = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        // Bytes corresponding to the decoded adderess. Computed using the Rust SDK.
        let expected = Data([16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191])
        XCTAssertEqual(a.bytes, expected)
    }

    func testCannotParseInvalidAddressString() async throws {
        XCTAssertThrowsError(try AccountAddress(base58Check: "invalid")) { err in
            XCTAssertEqual(err as! Base58CheckError, Base58CheckError.invalidDecoding)
        }
    }

    func testCannotParseAddressStringWithInvalidVersionByte() async throws {
        // Same address as above but with Base58Check version byte 2.
        XCTAssertThrowsError(try AccountAddress(base58Check: "51wUd1qZ9UKhiJQwab17sb5F3XgEy6vravJ2GPEHNYjHpncAjG")) { err in
            XCTAssertEqual(err as! GrpcError, GrpcError.unexpectedBase64CheckVersion(expected: 1, actual: 2))
        }
    }
}
