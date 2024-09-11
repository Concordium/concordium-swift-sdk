@testable import Concordium
import XCTest

let V0_PIGGYBANK_SCHEMA = "AQAAAAkAAABQaWdneUJhbmsBFQIAAAAGAAAASW50YWN0AgcAAABTbWFzaGVkAgAAAAAA";
let CIS2_WCCD_STATE_SCHEMA =
    "//8CAQAAAA8AAABDSVMyLXdDQ0QtU3RhdGUAAQAAAAoAAABnZXRCYWxhbmNlAhQAAQAAAAUAAABvd25lchUCAAAABwAAAEFjY291bnQBAQAAAAsIAAAAQ29udHJhY3QBAQAAAAwbJQAAAA==";
let CIS2_WCCD_STATE_GET_BALANCE_RETURN_VALUE_SCHEMA = "GyUAAAA";
let TEST_CONTRACT_SCHEMA = "//8CAQAAAAwAAABUZXN0Q29udHJhY3QBBAIDAQAAABAAAAByZWNlaXZlX2Z1bmN0aW9uBgYIBw==";
let TEST_CONTRACT_RECEIVE_ERROR_SCHEMA = "Bw=="; // i16
let TEST_CONTRACT_INIT_ERROR_SCHEMA = "Aw=="; // u16
let AUCTION_WITH_ERRORS_VIEW_RETURN_VALUE_SCHEMA =
    "FAAEAAAADQAAAGF1Y3Rpb25fc3RhdGUVAgAAAAoAAABOb3RTb2xkWWV0AgQAAABTb2xkAQEAAAALDgAAAGhpZ2hlc3RfYmlkZGVyFQIAAAAEAAAATm9uZQIEAAAAU29tZQEBAAAACwQAAABpdGVtFgIDAAAAZW5kDQ==";

// contract: "test", init = (param = u64), receive = (name: "receive", param = u64, return = u64)
let TEST_CONTRACT_U64 = "//8DAQAAAAQAAAB0ZXN0AQAFAQAAAAcAAAByZWNlaXZlAgUFAA==";


final class ContractTest: XCTestCase {
    func testModuleSchemaParse() throws {
        let contractName = try ContractName("test")
        let moduleSchema = try ModuleSchema(base64: TEST_CONTRACT_U64)
        XCTAssertEqual(moduleSchema.base64, TEST_CONTRACT_U64)

        let initParam = try moduleSchema.initParameterSchema(contractName: contractName)
        XCTAssertEqual(initParam.base64, "BQ==")
        let receiveParam = try moduleSchema.receiveParameterSchema(receiveName: ReceiveName(contractName: contractName, entrypoint: EntrypointName("receive")))
        XCTAssertEqual(receiveParam.base64, "BQ==")
        let receiveReturn = try moduleSchema.receiveReturnValueSchema(receiveName: ReceiveName(contractName: contractName, entrypoint: EntrypointName("receive")))
        XCTAssertEqual(receiveReturn.base64, "BQ==")

        XCTAssertThrowsError(try moduleSchema.initErrorSchema(contractName: contractName))
        XCTAssertThrowsError(try moduleSchema.receiveErrorSchema(receiveName: ReceiveName(contractName: contractName, entrypoint: EntrypointName("receive"))))
    }

    func testTypeSchemaTemplate() throws {
        let expected = """
        {"auction_state":{"Enum":[{"NotSoldYet":[]},{"Sold":["<AccountAddress>"]}]},"end":"<Timestamp (e.g. `2000-01-01T12:00:00Z`)>","highest_bidder":{"Enum":[{"None":[]},{"Some":["<AccountAddress>"]}]},"item":"<String>"}
        """
        let schema = try TypeSchema(base64: AUCTION_WITH_ERRORS_VIEW_RETURN_VALUE_SCHEMA)
        XCTAssertEqual(try schema.template, expected)
    }

    func testTypeSchemaConvert() throws {
        var schema = try TypeSchema(base64: TEST_CONTRACT_INIT_ERROR_SCHEMA)
        let u = try schema.decode(data: Data(hex: "ffff")).parse(UInt16.self)
        XCTAssertEqual(u, 65535)

        schema = try TypeSchema(base64: TEST_CONTRACT_RECEIVE_ERROR_SCHEMA)
        let i = try schema.decode(data: Data(hex: "ffff")).parse(Int16.self)
        XCTAssertEqual(i, -1)
    }
}
