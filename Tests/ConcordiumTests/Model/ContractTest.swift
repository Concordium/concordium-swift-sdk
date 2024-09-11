@testable import Concordium
import XCTest

let TEST_CONTRACT_SCHEMA = "//8CAQAAAAwAAABUZXN0Q29udHJhY3QBBAIDAQAAABAAAAByZWNlaXZlX2Z1bmN0aW9uBgYIBw=="
let TEST_CONTRACT_RECEIVE_ERROR_SCHEMA = "Bw==" // i16
let TEST_CONTRACT_INIT_ERROR_SCHEMA = "Aw==" // u16
let AUCTION_WITH_ERRORS_VIEW_RETURN_VALUE_SCHEMA =
    "FAAEAAAADQAAAGF1Y3Rpb25fc3RhdGUVAgAAAAoAAABOb3RTb2xkWWV0AgQAAABTb2xkAQEAAAALDgAAAGhpZ2hlc3RfYmlkZGVyFQIAAAAEAAAATm9uZQIEAAAAU29tZQEBAAAACwQAAABpdGVtFgIDAAAAZW5kDQ=="

// contract: "test", init = (param = u64), receive = (name: "receive", param = u64, return = u64)
let TEST_CONTRACT_U64 = "//8DAQAAAAQAAAB0ZXN0AQAFAQAAAAcAAAByZWNlaXZlAgUFAA=="

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

    func testSchemaEq() throws {
        let moduleSchema = try ModuleSchema(base64: TEST_CONTRACT_SCHEMA)

        var value = try moduleSchema.initErrorSchema(contractName: ContractName("TestContract"))
        var expected = try TypeSchema(base64: TEST_CONTRACT_INIT_ERROR_SCHEMA)
        XCTAssertEqual(value, expected)

        value = try moduleSchema.receiveErrorSchema(receiveName: ReceiveName(contractName: ContractName("TestContract"), entrypoint: EntrypointName("receive_function")))
        expected = try TypeSchema(base64: TEST_CONTRACT_RECEIVE_ERROR_SCHEMA)
        XCTAssertEqual(value, expected)
    }

    func testSimpleTypeSchemaConvert() throws {
        var schema = try TypeSchema(base64: TEST_CONTRACT_INIT_ERROR_SCHEMA)
        var u = try schema.decode(data: Data(hex: "ffff")).parse(UInt16.self)
        XCTAssertEqual(u, 65535)
        u = try schema.decode(data: Data(hex: "0100")).parse(UInt16.self)
        XCTAssertEqual(u, 1)

        schema = try TypeSchema(base64: TEST_CONTRACT_RECEIVE_ERROR_SCHEMA)
        let i = try schema.decode(data: Data(hex: "ffff")).parse(Int16.self)
        XCTAssertEqual(i, -1)
    }

    func testComplexTypeSchemaConvert() throws {
        let schema = try TypeSchema(base64: AUCTION_WITH_ERRORS_VIEW_RETURN_VALUE_SCHEMA)
        var json = """
        {"auction_state":{"NotSoldYet":[]},"end":"2000-01-01T12:00:00+00:00","highest_bidder":{"None":[]},"item":"Test item"}
        """
        var value = try schema.encode(json: json)
        var expected = try Data(hex: "00000900000054657374206974656d00da626ddc000000")
        XCTAssertEqual(value, expected)
        XCTAssertEqual(try schema.decode(data: expected).value, json)

        json = """
        {"auction_state":{"Sold":["35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh"]},"end":"2000-01-01T12:00:00+00:00","highest_bidder":{"Some":["35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh"]},"item":"Test item"}
        """
        value = try schema.encode(json: json)
        expected = try Data(hex: "0110eac3f30aa2489508c86eb09328ff8a5475f9fe5c9458cc3c70956fcfcb22bf0110eac3f30aa2489508c86eb09328ff8a5475f9fe5c9458cc3c70956fcfcb22bf0900000054657374206974656d00da626ddc000000")

        XCTAssertEqual(value, expected)
        XCTAssertEqual(try schema.decode(data: expected).value, json)
    }
}
