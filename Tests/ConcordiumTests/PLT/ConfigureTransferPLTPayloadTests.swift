import BigInt
@testable import Concordium
import Foundation
import SwiftCBOR
import XCTest

final class ConfigureTransferPLTPayloadTests: XCTestCase {
    func testConfigureTransferPLTPayloadWithMemo() throws {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_500_000), decimals: 6)
        let receiverData = try Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )
        let memo = PLT.CborMemo(string: "My memo")

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver, memo: memo)
        let hex = payload.toCBORData().hexEncodedString()

        let validHexes = [
            "a1687472616e73666572a366616d6f756e74c482251a0016e360646d656d6fd81848674d79206d656d6f69726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a1687472616e73666572a3646d656d6fd81848674d79206d656d6f69726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360",
            "a1687472616e73666572a366616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7646d656d6fd81848674d79206d656d6f",
            "a1687472616e73666572a369726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7646d656d6fd81848674d79206d656d6f66616d6f756e74c482251a0016e360",
            "a1687472616e73666572a269726563697069656e74d99d73a1035820151515151515151515151515151515151515151515151515151515151515151566616d6f756e74c48223187b",
            "a1687472616e73666572a369726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360646d656d6fd81848674d79206d656d6f",
            "a1687472616e73666572a3646d656d6fd81848674d79206d656d6f66616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a3646d656d6fd818474d79206d656d6f66616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a366616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7646d656d6fd818474d79206d656d6f",
            "a369726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7646d656d6fd818474d79206d656d6f66616d6f756e74c482251a0016e360",
            "a366616d6f756e74c482251a0016e360646d656d6fd818474d79206d656d6f69726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a369726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360646d656d6fd818474d79206d656d6f",
            "a3646d656d6fd818474d79206d656d6f69726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360",
        ]

        XCTAssertTrue(validHexes.contains(hex), "Unexpected CBOR hex:\n\(hex)")
    }

    func testConfigureTransferPLTPayloadWithoutMemo() throws {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_500_000), decimals: 6)
        let receiverData = try Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let hex = payload.toCBORData().hexEncodedString()

        let validHexes = [
            "a1687472616e73666572a269726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360",
            "a1687472616e73666572a266616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a266616d6f756e74c482251a0016e36069726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7",
            "a269726563697069656e74d99d73a103582021bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b766616d6f756e74c482251a0016e360",
        ]

        XCTAssertTrue(validHexes.contains(hex), "Unexpected CBOR hex:\n\(hex)")
    }

    func testConfigureTransferPLTPayloadWithoutMemo_ShortValue() throws {
        let amount = PLT.TokenOperationAmount(value: BigUInt(123), decimals: 4)
        let receiverData = try Data(hex: "1515151515151515151515151515151515151515151515151515151515151515")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let hex = payload.toCBORData().hexEncodedString()

        let validHexes = [
            "a1687472616e73666572a266616d6f756e74c48223187b69726563697069656e74d99d73a10358201515151515151515151515151515151515151515151515151515151515151515",
            "a1687472616e73666572a269726563697069656e74d99d73a1035820151515151515151515151515151515151515151515151515151515151515151566616d6f756e74c48223187b",
            "a266616d6f756e74c48223187b69726563697069656e74d99d73a10358201515151515151515151515151515151515151515151515151515151515151515",
            "a269726563697069656e74d99d73a1035820151515151515151515151515151515151515151515151515151515151515151566616d6f756e74c48223187b",
        ]

        XCTAssertTrue(validHexes.contains(hex), "Unexpected CBOR hex:\n\(hex)")
    }
}

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
