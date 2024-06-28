@testable import Concordium
import XCTest

final class TransactionTest: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testDeployModuleSerialization() throws {
        let t = AccountTransactionPayload.deployModule(WasmModule(version: WasmVersion.v1, source: Data([1, 2, 3, 50])))

        // Generated from serializing payload in rust sdk
        let expected = Data([0, 0, 0, 0, 1, 0, 0, 0, 4, 1, 2, 3, 50])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    func testInitContractSerialization() throws {
        let modRef = try ModuleReference(fromHex: "c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38")
        let t = try AccountTransactionPayload.initContract(amount: 1234, modRef: modRef, initName: InitName("init_test"), param: Parameter(Data([123, 23, 12, 45, 56])))

        // Generated from serializing payload in rust sdk
        let expected = Data([1, 0, 0, 0, 0, 0, 0, 4, 210, 193, 78, 251, 202, 29, 207, 49, 76, 115, 204, 41, 76, 187, 241, 189, 99, 227, 144, 107, 32, 211, 84, 66, 148, 62, 185, 47, 82, 227, 131, 252, 56, 0, 9, 105, 110, 105, 116, 95, 116, 101, 115, 116, 0, 5, 123, 23, 12, 45, 56])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    func testUpdateContractSerialization() throws {
        let contractAddress = ContractAddress(index: 123, subindex: 0)
        let t = try AccountTransactionPayload.updateContract(amount: 4321, contractAddress: contractAddress, receiveName: ReceiveName("test.function"), message: Parameter(Data([123, 23, 12, 45, 56])))

        // Generated from serializing payload in rust sdk
        let expected = Data([2, 0, 0, 0, 0, 0, 0, 16, 225, 0, 0, 0, 0, 0, 0, 0, 123, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 116, 101, 115, 116, 46, 102, 117, 110, 99, 116, 105, 111, 110, 0, 5, 123, 23, 12, 45, 56])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    func testTransferSerialization() throws {
        let a = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        var t = AccountTransactionPayload.transfer(amount: 100, receiver: a, memo: nil)

        // Generated from serializing payload in rust sdk
        var expected = Data([3, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 0, 0, 0, 0, 0, 0, 100])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)

        t = AccountTransactionPayload.transfer(amount: 100, receiver: a, memo: Memo(value: Data([0, 23, 55])))
        // Generated from serializing payload in rust sdk
        expected = Data([22, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 3, 0, 23, 55, 0, 0, 0, 0, 0, 0, 0, 100])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    func testTransferWithScheduleSerialization() throws {
        let a = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        let schedule: [ScheduledTransfer] = [ScheduledTransfer(timestamp: 123_456, amount: 23), ScheduledTransfer(timestamp: 234_456, amount: 1234)]
        var t = AccountTransactionPayload.transferWithSchedule(receiver: a, schedule: schedule)

        // Generated from serializing payload in rust sdk
        var expected = Data([19, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 2, 0, 0, 0, 0, 0, 1, 226, 64, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 3, 147, 216, 0, 0, 0, 0, 0, 0, 4, 210])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)

        t = AccountTransactionPayload.transferWithSchedule(receiver: a, schedule: schedule, memo: Memo(value: Data([1, 2, 3, 4])))
        // Generated from serializing payload in rust sdk
        expected = Data([24, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 4, 1, 2, 3, 4, 2, 0, 0, 0, 0, 0, 1, 226, 64, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 3, 147, 216, 0, 0, 0, 0, 0, 0, 4, 210])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }
}
