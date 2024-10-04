@testable import Concordium
import Foundation
import XCTest

final class CIS0Test: XCTestCase {
    func testSerializeSupportsParam() throws {
        let param = CIS0.SupportsParam([CIS0.StandardIdentifier(id: "CIS-0")!, CIS0.StandardIdentifier(id: "CIS-2")!])
        let data = param.serialize()
        let expected = try Data(hex: "0002054349532d30054349532d32")
        XCTAssertEqual(data, expected)
    }

    func testDeserializeSupportsResponse() throws {
        let value = try CIS0.SupportsResponse.deserialize(Data(hex: "0300010002027b00000000000000000000000000000041010000000000000c00000000000000")).elements
        let expected: [CIS0.SupportResult] = [.supported, .notSupported, .supportedBy(contracts: [ContractAddress(index: 123, subindex: 0), ContractAddress(index: 321, subindex: 12)])]
        XCTAssertEqual(value, expected)
    }
}
