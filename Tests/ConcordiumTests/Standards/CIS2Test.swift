@testable import Concordium
import Foundation
import XCTest

private let account = try! AccountAddress(Data([2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]))

final class CIS2Test: XCTestCase {
    func testSerializeBalanceOfParam() throws {
        let value = CIS2.BalanceOfParam([
            CIS2.BalanceOfQuery(tokenId: CIS2.TokenID(Data([23]))!, address: .account(account)),
            CIS2.BalanceOfQuery(tokenId: CIS2.TokenID(Data([1]))!, address: .contract(ContractAddress(index: 123, subindex: 543))),
        ]).contractSerialize()
        let expected = try Data(hex: "020001170002020202020202020202020202020202020202020202020202020202020202020101017b000000000000001f02000000000000")
        XCTAssertEqual(value, expected)
    }

    func testDeserializeBalanceOfResponse() throws {
        let value = try CIS2.BalanceOfResponse.contractDeserialize(Data(hex: "0200b96000")).elements
        let expected = [CIS2.TokenAmount(12345)!, CIS2.TokenAmount(0)]
        XCTAssertEqual(value, expected)
    }

    func testSerializeTransferParam() throws {
        let value = CIS2.TransferParam([
            CIS2.TransferPayload(tokenId: CIS2.TokenID(Data([12]))!, amount: CIS2.TokenAmount(12345)!, sender: Address.account(account), receiver: CIS2.Receiver.account(account), data: nil),
            CIS2.TransferPayload(tokenId: CIS2.TokenID(Data([0]))!, amount: CIS2.TokenAmount(12345)!, sender: Address.contract(ContractAddress(index: 1, subindex: 2)), receiver: CIS2.Receiver.contract(ContractAddress(index: 12, subindex: 0), hookName: ReceiveName(unchecked: "test.receive")), data: Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
        ]).contractSerialize()
        let expected = try Data(hex: "0200010cb96000020202020202020202020202020202020202020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202020200000100b9600101000000000000000200000000000000010c0000000000000000000000000000000c00746573742e726563656976650a000102030405060708090a")
        XCTAssertEqual(value, expected)
    }

    func testSerializeTokenMetadataParam() throws {
        let value = CIS2.TokenMetadataParam([
            CIS2.TokenID(Data([0]))!,
        ]).contractSerialize()
        let expected = try Data(hex: "01000100")
        XCTAssertEqual(value, expected)
    }

    func testDeserializeTokenMetadataResponse() throws {
        let value = try CIS2.TokenMetadataResponse.contractDeserialize(Data(hex: "0200120068747470733a2f2f676f6f676c652e636f6d00160068747470733a2f2f636f6e636f726469756d2e636f6d013737373737373737373737373737373737373737373737373737373737373737")).elements
        let expected = try [CIS2.TokenMetadataUrl(url: URL(string: "https://google.com")!), CIS2.TokenMetadataUrl(url: URL(string: "https://concordium.com")!, checksum: Data(hex: "3737373737373737373737373737373737373737373737373737373737373737"))]
        XCTAssertEqual(value, expected)
    }
}
