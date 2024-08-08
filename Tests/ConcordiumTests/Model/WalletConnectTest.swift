@testable import Concordium
import XCTest

let encoder = JSONEncoder()

final class WalletConnectTest: XCTestCase {
    func testDeployModuleCodable() throws {
        let json = """
        {"source":"01020332","version":1}
        """.data(using: .utf8)!

        let decoded = try WalletConnectPayload(json: json, assuming: TransactionType.deployModule)
        let expected = WalletConnectPayload.deployModule(WasmModule(version: WasmVersion.v1, source: Data([1, 2, 3, 50])))
        XCTAssertEqual(decoded, expected)
        // ID test
        XCTAssertEqual(try WalletConnectPayload(json: try! encoder.encode(expected), assuming: TransactionType.deployModule), expected)
    }

    func testInitContractCodable() throws {
        let modRef = try ModuleReference(fromHex: "c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38")

        let json = """
        {"amount":"1234","moduleRef":"c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38","initName":"init_test","param":"7b170c2d38","maxContractExecutionEnergy":30000}
        """.data(using: .utf8)!
        let decoded = try WalletConnectPayload(json: json, assuming: TransactionType.initContract)
        let expected = try WalletConnectPayload.initContract(amount: CCD(microCCD: 1234), modRef: modRef, initName: InitName("init_test"), param: Parameter(Data([123, 23, 12, 45, 56])), maxEnergy: 30000)
        XCTAssertEqual(decoded, expected)
        // ID test
        XCTAssertEqual(try WalletConnectPayload(json: try! encoder.encode(expected), assuming: TransactionType.initContract), expected)
    }

    func testUpdateContractCodable() throws {
        let contractAddress = ContractAddress(index: 123, subindex: 2)

        let json = """
        {"amount":"1234","address":{"index":123,"subindex":2},"receiveName":"test.abc","message":"7b170c2d38","maxContractExecutionEnergy":30000}
        """.data(using: .utf8)!
        let decoded = try WalletConnectPayload(json: json, assuming: TransactionType.updateContract)
        let expected = try WalletConnectPayload.updateContract(amount: CCD(microCCD: 1234), address: contractAddress, receiveName: ReceiveName(unchecked: "test.abc"), message: Parameter(Data([123, 23, 12, 45, 56])), maxEnergy: 30000)
        XCTAssertEqual(decoded, expected)
        // ID test
        XCTAssertEqual(try WalletConnectPayload(json: try! encoder.encode(expected), assuming: TransactionType.updateContract), expected)
    }
}
