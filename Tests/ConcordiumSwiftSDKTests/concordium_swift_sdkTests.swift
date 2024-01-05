@testable import ConcordiumSwiftSDK
import XCTest

final class concordium_swift_sdkTests: XCTestCase {
    func testParameterToJsonSuccess() throws {
        let inputJson =
                """
                {
                    "parameter": "0063aaa94f7e272aa57929720d24c1250debb94c1860386fcc1e36c6fc804b95fa0000",
                    "receiveName": "cis2_wCCD.wrap",
                    "schema": {
                        "type": "parameter",
                        "value": "FAACAAAAAgAAAHRvFQIAAAAHAAAAQWNjb3VudAEBAAAACwgAAABDb250cmFjdAECAAAADBYBBAAAAGRhdGEQAQI="
                    }
                }
                """
        let expectedOutput =
                """
                {"data":[],"to":{"Account":["3he2aDi8GT9bLZTVfY3CD36JUsXBt8QaqvRW8AW4SpstdPYFzu"]}}
                """
        XCTAssertEqual(try parameterToJson(inputJson), expectedOutput)
    }

    func testParameterToJsonFailure() {
        XCTAssertThrowsError(try parameterToJson("garbage")) { err in
            XCTAssertEqual(err as! MobileWalletError, MobileWalletError.failed("Could not produce response: expected value at line 1 column 1"))
        }
    }
}
