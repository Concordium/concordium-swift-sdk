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
        let t = try AccountTransactionPayload.updateContract(amount: 4321, address: contractAddress, receiveName: ReceiveName("test.function"), message: Parameter(Data([123, 23, 12, 45, 56])))

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

        t = AccountTransactionPayload.transfer(amount: 100, receiver: a, memo: Memo(Data([0, 23, 55])))
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

        t = AccountTransactionPayload.transferWithSchedule(receiver: a, schedule: schedule, memo: Memo(Data([1, 2, 3, 4])))
        // Generated from serializing payload in rust sdk
        expected = Data([24, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 4, 1, 2, 3, 4, 2, 0, 0, 0, 0, 0, 1, 226, 64, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 3, 147, 216, 0, 0, 0, 0, 0, 0, 4, 210])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    func testRegisterDataSerialization() throws {
        let t = try AccountTransactionPayload.registerData(RegisteredData(Data([123, 231, 222, 0, 1, 2])))

        // Generated from serializing payload in rust sdk
        let expected = Data([21, 0, 6, 123, 231, 222, 0, 1, 2])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

//    func testTransferToPublicSerialization() throws {}

    func testUpdateCredentialKeysSerialization() throws {
        let credId = try CredentialRegistrationID(Data(hex: "a5727a5f217a0abaa6bba7f6037478051a49d5011e045eb0d86fce393e0c7b4a96382c60e09a489ebb6d800dc0d88d05"))
        let keys = try CredentialPublicKeys(keys: [2: VerifyKey(ed25519KeyHex: "d684ac5fd786d33c82701ce9f05017bb6f3114bec77c0e836e7d5c211de9acc6")], threshold: 1)
        let t = AccountTransactionPayload.updateCredentialKeys(credId: credId, keys: keys)

        let expected = Data([13, 165, 114, 122, 95, 33, 122, 10, 186, 166, 187, 167, 246, 3, 116, 120, 5, 26, 73, 213, 1, 30, 4, 94, 176, 216, 111, 206, 57, 62, 12, 123, 74, 150, 56, 44, 96, 224, 154, 72, 158, 187, 109, 128, 13, 192, 216, 141, 5, 1, 2, 0, 214, 132, 172, 95, 215, 134, 211, 60, 130, 112, 28, 233, 240, 80, 23, 187, 111, 49, 20, 190, 199, 124, 14, 131, 110, 125, 92, 33, 29, 233, 172, 198, 1])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }

    // func testUpdateCredentialsSerialization() throws { }
    // func testConfigureBakerSerialization() throws { }
    func testConfigureDelegationSerialization() throws {
        var data = ConfigureDelegationPayload(capital: 12_000_000, delegationTarget: DelegationTarget.passive)
        var t = AccountTransactionPayload.configureDelegation(data)

        var expected = Data([26, 0, 5, 0, 0, 0, 0, 0, 183, 27, 0, 0])
        var actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)

        data = ConfigureDelegationPayload(delegationTarget: DelegationTarget.baker(1234))
        t = AccountTransactionPayload.configureDelegation(data)

        expected = Data([26, 0, 4, 1, 0, 0, 0, 0, 0, 0, 4, 210])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)

        data = ConfigureDelegationPayload(capital: 432, restakeEarnings: true, delegationTarget: DelegationTarget.baker(12))
        t = AccountTransactionPayload.configureDelegation(data)

        expected = Data([26, 0, 7, 0, 0, 0, 0, 0, 0, 1, 176, 1, 1, 0, 0, 0, 0, 0, 0, 0, 12])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected)!, t)
    }
}
