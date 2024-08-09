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
    func testDeployModuleDecode() throws {
        var type = TransactionTypeString.deployModule
        var tJson = """
        {"source":"01020332","version":1}
        """
        var json = makePayloadJson(type: type, transactionPayloadJson: tJson)
        var decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)

        var tExpected = WalletConnectTransactionPayload.deployModule(version: WasmVersion.v1, source: Data([1, 2, 3, 50]))
        var expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)

        type = TransactionTypeString.deployModule
        tJson = """
        {"source":"01020332"}
        """
        json = makePayloadJson(type: type, transactionPayloadJson: tJson)
        decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)

        tExpected = WalletConnectTransactionPayload.deployModule(version: nil, source: Data([1, 2, 3, 50]))
        expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }

    func testInitContractDecode() throws {
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

    func testUpdateContractDecode() throws {
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

    func testTransferDecode() throws {
        var type = TransactionTypeString.transfer

        var tJson = """
        {"amount":"1234","toAddress":"\(account)"}
        """
        var json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        var decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        var tExpected = WalletConnectTransactionPayload.transfer(amount: CCD(microCCD: 1234), receiver: account)
        var expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)

        type = TransactionTypeString.transferWithMemo

        tJson = """
        {"amount":"1234","toAddress":"\(account)", "memo": "010203"}
        """
        json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        tExpected = WalletConnectTransactionPayload.transfer(amount: CCD(microCCD: 1234), receiver: account, memo: Memo(Data([1, 2, 3])))
        expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }

    func testTransferWithScheduleDecode() throws {
        var type = TransactionTypeString.transferWithSchedule

        var tJson = """
        {"schedule":[[1234, "4321"]],"toAddress":"\(account)"}
        """
        var json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        var decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        var tExpected = WalletConnectTransactionPayload.transferWithSchedule(receiver: account, schedule: [ScheduledTransfer(timestamp: 1234, amount: CCD(microCCD: 4321))])
        var expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)

        type = TransactionTypeString.transferWithScheduleAndMemo

        tJson = """
        {"schedule":[[1234, "4321"]],"toAddress":"\(account)", "memo": "010203"}
        """
        json = makePayloadJson(type: type, transactionPayloadJson: tJson)

        decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)
        tExpected = WalletConnectTransactionPayload.transferWithSchedule(receiver: account, schedule: [ScheduledTransfer(timestamp: 1234, amount: CCD(microCCD: 4321))], memo: Memo(Data([1, 2, 3])))
        expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }

    func testRegisterDataDecode() throws {
        let type = TransactionTypeString.registerData
        let data = "test".data(using: .utf8)!
        let tJson = """
        {"data":"\(data.hex)"}
        """
        let json = makePayloadJson(type: type, transactionPayloadJson: tJson)
        let decoded = try decoder.decode(WalletConnectSendTransactionParam.self, from: json)

        let tExpected = WalletConnectTransactionPayload.registerData(RegisteredData(unchecked: data))
        let expected = makeExpectedPayload(type: type, transactionPayload: tExpected)
        XCTAssertEqual(decoded, expected)
    }
}
