@testable import Concordium
import XCTest

let decoder = JSONDecoder()

let account = try! AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")

func makePayloadJson(type: TransactionTypeString, transactionPayloadJson: String) -> Data {
    """
    {
        "type": "\(type)",
        "sender": "\(account)",
        "payload": \(transactionPayloadJson),
    }
    """.data(using: .utf8)!
}

func makeExpectedPayload(type: TransactionTypeString, transactionPayload: WalletConnectTransactionPayload) -> WalletConnectSendTransactionParam {
    WalletConnectSendTransactionParam(type: type.transactionType, sender: account, payload: transactionPayload)
}

final class WalletConnectTest: XCTestCase {
    func testDeployModuleCodable() throws {
        let type = TransactionTypeString.deployModule
        let tJson = """
        {"source":"01020332","version":1}
        """
        let json = makePayloadJson(type: type, transactionPayloadJson: tJson)
        let decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)

        let tExpected = WalletConnectTransactionPayload.deployModule(WasmModule(version: WasmVersion.v1, source: Data([1, 2, 3, 50])))
        let expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }

    func testInitContractCodable() throws {
        let type = TransactionTypeString.initContract
        let modRef = try ModuleReference(fromHex: "c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38")

        let tJson = """
        {"amount":"1234","moduleRef":"c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38","initName":"init_test","param":"7b170c2d38","maxContractExecutionEnergy":30000}
        """
        let json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        let decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        let tExpected = try WalletConnectTransactionPayload.initContract(amount: CCD(microCCD: 1234), modRef: modRef, initName: InitName("init_test"), param: Parameter(Data([123, 23, 12, 45, 56])), maxEnergy: 30000)
        let expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }

    func testUpdateContractCodable() throws {
        let type = TransactionTypeString.updateContract
        let contractAddress = ContractAddress(index: 123, subindex: 2)

        let tJson = """
        {"amount":"1234","address":{"index":123,"subindex":2},"receiveName":"test.abc","message":"7b170c2d38","maxContractExecutionEnergy":30000}
        """
        let json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        let decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        let tExpected = try WalletConnectTransactionPayload.updateContract(amount: CCD(microCCD: 1234), address: contractAddress, receiveName: ReceiveName(unchecked: "test.abc"), message: Parameter(Data([123, 23, 12, 45, 56])), maxEnergy: 30000)
        let expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }
}
