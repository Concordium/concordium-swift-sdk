@testable import Concordium
import Foundation
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
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testInitContractSerialization() throws {
        let modRef = try ModuleReference(fromHex: "c14efbca1dcf314c73cc294cbbf1bd63e3906b20d35442943eb92f52e383fc38")
        let t = try AccountTransactionPayload.initContract(amount: 1234, modRef: modRef, initName: InitName("init_test"), param: Parameter(Data([123, 23, 12, 45, 56])))

        // Generated from serializing payload in rust sdk
        let expected = Data([1, 0, 0, 0, 0, 0, 0, 4, 210, 193, 78, 251, 202, 29, 207, 49, 76, 115, 204, 41, 76, 187, 241, 189, 99, 227, 144, 107, 32, 211, 84, 66, 148, 62, 185, 47, 82, 227, 131, 252, 56, 0, 9, 105, 110, 105, 116, 95, 116, 101, 115, 116, 0, 5, 123, 23, 12, 45, 56])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testUpdateContractSerialization() throws {
        let contractAddress = ContractAddress(index: 123, subindex: 0)
        let t = try AccountTransactionPayload.updateContract(amount: 4321, address: contractAddress, receiveName: ReceiveName("test.function"), message: Parameter(Data([123, 23, 12, 45, 56])))

        // Generated from serializing payload in rust sdk
        let expected = Data([2, 0, 0, 0, 0, 0, 0, 16, 225, 0, 0, 0, 0, 0, 0, 0, 123, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 116, 101, 115, 116, 46, 102, 117, 110, 99, 116, 105, 111, 110, 0, 5, 123, 23, 12, 45, 56])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testTransferSerialization() throws {
        let a = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        var t = AccountTransactionPayload.transfer(amount: 100, receiver: a, memo: nil)

        // Generated from serializing payload in rust sdk
        var expected = Data([3, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 0, 0, 0, 0, 0, 0, 100])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        t = AccountTransactionPayload.transfer(amount: 100, receiver: a, memo: Memo(Data([0, 23, 55])))
        // Generated from serializing payload in rust sdk
        expected = Data([22, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 3, 0, 23, 55, 0, 0, 0, 0, 0, 0, 0, 100])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testTransferWithScheduleSerialization() throws {
        let a = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        let schedule: [ScheduledTransfer] = [ScheduledTransfer(timestamp: 123_456, amount: 23), ScheduledTransfer(timestamp: 234_456, amount: 1234)]
        var t = AccountTransactionPayload.transferWithSchedule(receiver: a, schedule: schedule)

        // Generated from serializing payload in rust sdk
        var expected = Data([19, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 2, 0, 0, 0, 0, 0, 1, 226, 64, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 3, 147, 216, 0, 0, 0, 0, 0, 0, 4, 210])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        t = AccountTransactionPayload.transferWithSchedule(receiver: a, schedule: schedule, memo: Memo(Data([1, 2, 3, 4])))
        // Generated from serializing payload in rust sdk
        expected = Data([24, 16, 234, 195, 243, 10, 162, 72, 149, 8, 200, 110, 176, 147, 40, 255, 138, 84, 117, 249, 254, 92, 148, 88, 204, 60, 112, 149, 111, 207, 203, 34, 191, 0, 4, 1, 2, 3, 4, 2, 0, 0, 0, 0, 0, 1, 226, 64, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 3, 147, 216, 0, 0, 0, 0, 0, 0, 4, 210])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testRegisterDataSerialization() throws {
        let t = try AccountTransactionPayload.registerData(RegisteredData(Data([123, 231, 222, 0, 1, 2])))

        // Generated from serializing payload in rust sdk
        let expected = Data([21, 0, 6, 123, 231, 222, 0, 1, 2])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testTransferToPublicSerialization() throws {
        // The following variables were generated using the rust SDK
        let remainingAmount = Data([152, 42, 172, 135, 45, 247, 101, 240, 62, 167, 48, 72, 158, 57, 227, 117, 102, 82, 163, 65, 59, 215, 239, 167, 154, 88, 54, 99, 61, 17, 246, 44, 33, 224, 1, 251, 29, 115, 231, 200, 33, 248, 30, 116, 189, 205, 255, 205, 161, 32, 186, 235, 210, 21, 97, 88, 174, 247, 132, 24, 71, 255, 175, 166, 118, 180, 239, 152, 15, 32, 240, 239, 88, 194, 171, 175, 130, 168, 79, 83, 172, 41, 101, 149, 116, 243, 38, 79, 244, 203, 40, 138, 136, 38, 86, 21, 167, 124, 78, 40, 196, 63, 68, 82, 119, 153, 232, 152, 229, 135, 248, 7, 197, 245, 132, 60, 229, 14, 38, 199, 144, 42, 166, 66, 173, 205, 182, 78, 101, 23, 172, 253, 119, 245, 157, 110, 97, 69, 128, 33, 52, 55, 149, 78, 153, 219, 209, 88, 152, 222, 31, 186, 168, 175, 149, 119, 33, 67, 251, 74, 197, 192, 151, 200, 88, 25, 237, 16, 109, 85, 97, 130, 172, 145, 1, 163, 20, 9, 228, 213, 13, 160, 144, 193, 21, 33, 237, 145, 206, 161, 98, 187])
        let transferAmount: MicroCCDAmount = 1_575_170_280_934_013_993
        let index: UInt64 = 827_975_603_961_802_779
        let proof = Data([44, 6, 123, 161, 10, 55, 193, 218, 243, 86, 86, 47, 52, 225, 68, 174, 209, 79, 37, 35, 19, 85, 139, 89, 125, 71, 239, 195, 118, 28, 0, 79, 107, 61, 158, 206, 19, 77, 102, 10, 14, 112, 83, 231, 68, 46, 8, 162, 40, 46, 17, 158, 72, 52, 159, 184, 206, 81, 22, 79, 165, 34, 31, 193, 0, 0, 0, 1, 108, 249, 82, 182, 203, 100, 13, 191, 169, 82, 88, 51, 133, 204, 63, 252, 185, 213, 242, 237, 83, 56, 234, 88, 155, 95, 39, 210, 164, 23, 250, 99, 57, 226, 161, 244, 221, 118, 67, 74, 38, 157, 81, 179, 27, 232, 207, 27, 18, 173, 83, 128, 36, 208, 10, 170, 87, 114, 84, 240, 100, 196, 245, 137, 0, 0, 0, 2, 40, 195, 133, 183, 176, 103, 51, 44, 48, 86, 216, 230, 4, 217, 132, 121, 179, 19, 189, 172, 209, 20, 36, 179, 182, 82, 47, 4, 252, 155, 87, 32, 34, 209, 21, 46, 249, 4, 103, 142, 94, 16, 196, 2, 173, 228, 76, 201, 60, 191, 161, 187, 194, 66, 71, 49, 16, 101, 253, 150, 16, 129, 135, 235, 73, 243, 165, 139, 75, 227, 45, 145, 14, 157, 205, 102, 48, 94, 17, 132, 144, 209, 254, 115, 157, 76, 245, 99, 50, 41, 213, 229, 121, 49, 109, 56, 103, 10, 98, 24, 245, 130, 140, 227, 81, 158, 67, 251, 40, 238, 235, 67, 153, 100, 61, 91, 235, 2, 249, 229, 126, 64, 103, 32, 228, 58, 115, 218, 135, 31, 229, 166, 211, 13, 152, 223, 182, 20, 206, 229, 105, 252, 222, 108, 67, 139, 27, 224, 64, 214, 18, 135, 119, 22, 125, 58, 179, 87, 13, 166, 67, 70, 34, 167, 169, 177, 42, 120, 50, 140, 97, 66, 103, 142, 215, 60, 130, 94, 139, 49, 33, 65, 184, 5, 88, 72, 200, 222, 148, 63, 249, 244, 186, 122, 70, 241, 36, 50, 144, 94, 127, 96, 12, 211, 20, 154, 140, 244, 134, 249, 106, 240, 5, 3, 6, 47, 1, 81, 155, 196, 185, 14, 177, 113, 141, 156, 87, 234, 145, 149, 1, 197, 34, 138, 189, 177, 194, 45, 238, 195, 154, 162, 233, 255, 167, 0, 188, 177, 128, 0, 128, 161, 169, 112, 223, 255, 70, 143, 249, 14, 150, 128, 218, 9, 41, 59, 165, 163, 237, 59, 71, 135, 138, 245, 160, 56, 193, 52, 222, 207, 152, 216, 145, 255, 161, 175, 150, 139, 38, 167, 116, 23, 247, 59, 34, 192, 24, 52, 77, 246, 113, 93, 73, 51, 24, 17, 74, 75, 13, 34, 134, 67, 123, 77, 151, 111, 5, 223, 140, 117, 64, 210, 209, 91, 150, 239, 11, 145, 175, 51, 146, 33, 213, 161, 189, 27, 6, 21, 90, 138, 191, 72, 3, 31, 25, 85, 162, 19, 86, 15, 100, 182, 82, 117, 78, 22, 200, 33, 176, 36, 137, 58, 147, 139, 157, 127, 159, 143, 206, 102, 194, 178, 193, 149, 136, 47, 68, 243, 71, 219, 189, 123, 155, 2, 56, 182, 21, 49, 32, 19, 158, 6, 116, 149, 97, 145, 133, 119, 127, 72, 226, 97, 99, 176, 191, 92, 254, 154, 210, 123, 42, 223, 173, 19, 79, 38, 0, 0, 0, 6, 132, 57, 77, 169, 163, 225, 41, 244, 118, 130, 25, 135, 181, 155, 101, 8, 12, 123, 19, 59, 167, 141, 3, 46, 87, 158, 63, 38, 157, 14, 192, 133, 60, 21, 101, 211, 204, 31, 218, 64, 174, 23, 251, 177, 214, 170, 93, 24, 172, 237, 210, 198, 177, 70, 111, 90, 91, 232, 65, 130, 140, 192, 186, 209, 158, 85, 29, 111, 136, 4, 107, 220, 185, 125, 149, 107, 213, 233, 59, 124, 44, 148, 41, 117, 32, 234, 49, 247, 10, 73, 46, 197, 157, 6, 104, 184, 171, 191, 10, 157, 191, 172, 72, 97, 96, 27, 134, 127, 117, 41, 6, 231, 153, 229, 251, 115, 103, 119, 137, 11, 24, 101, 235, 174, 174, 8, 31, 113, 15, 203, 166, 57, 160, 190, 31, 11, 98, 240, 205, 187, 102, 133, 100, 147, 163, 50, 163, 68, 219, 197, 11, 242, 89, 207, 114, 22, 153, 151, 119, 249, 60, 39, 108, 182, 134, 187, 166, 161, 156, 13, 146, 190, 166, 106, 83, 172, 59, 214, 227, 71, 69, 188, 13, 175, 13, 98, 143, 225, 240, 28, 41, 229, 150, 252, 126, 32, 36, 192, 243, 71, 34, 154, 189, 126, 231, 181, 136, 55, 14, 49, 225, 136, 45, 120, 66, 199, 169, 213, 137, 88, 104, 78, 255, 87, 28, 22, 147, 72, 167, 31, 75, 103, 85, 67, 1, 10, 18, 112, 151, 196, 130, 178, 42, 159, 241, 162, 85, 209, 93, 220, 42, 54, 72, 125, 32, 199, 115, 147, 87, 87, 222, 139, 33, 107, 150, 42, 236, 29, 194, 253, 104, 206, 253, 184, 6, 192, 184, 219, 188, 207, 254, 114, 175, 123, 133, 86, 121, 224, 164, 115, 244, 124, 43, 132, 18, 216, 252, 240, 47, 69, 215, 147, 69, 114, 28, 23, 74, 46, 101, 240, 237, 229, 36, 7, 50, 215, 105, 93, 92, 227, 38, 80, 43, 231, 50, 183, 134, 254, 85, 111, 83, 246, 241, 182, 135, 4, 162, 131, 163, 123, 41, 133, 249, 247, 83, 214, 240, 224, 175, 111, 139, 54, 155, 147, 132, 17, 234, 137, 188, 240, 251, 113, 223, 51, 139, 113, 59, 137, 71, 74, 19, 19, 14, 160, 142, 230, 187, 135, 243, 16, 99, 79, 198, 93, 185, 79, 123, 144, 70, 43, 37, 185, 54, 159, 145, 47, 234, 165, 18, 96, 149, 46, 90, 1, 137, 117, 176, 235, 205, 34, 191, 32, 133, 93, 53, 80, 110, 228, 239, 134, 132, 139, 179, 145, 189, 233, 200, 87, 246, 80, 194, 97, 143, 190, 232, 215, 247, 178, 246, 228, 123, 160, 192, 214, 61, 86, 201, 121, 195, 251, 117, 7, 87, 42, 64, 113, 252, 127, 1, 207, 167, 6, 216, 95, 36, 20, 160, 191, 254, 95, 58, 162, 22, 67, 87, 235, 120, 34, 202, 245, 165, 42, 172, 65, 139, 182, 242, 57, 76, 54, 219, 64, 122, 43, 23, 98, 196, 100, 129, 132, 2, 86, 221, 195, 83, 222, 22, 84, 130, 213, 19, 179, 172, 109, 1, 250, 211, 42, 154, 156, 224, 189, 76, 0, 132, 250, 33, 140, 176, 119, 4, 153, 121, 180, 39, 85, 75, 178, 170, 25, 229, 69, 171, 140, 46, 177, 249, 163, 132, 165, 45, 208, 109, 225, 190, 206, 252, 172, 124, 164, 180, 133, 226, 121, 112, 64, 108, 131, 200, 47, 115, 106, 13, 19, 136, 162, 46, 55, 65, 136, 80, 100, 228, 176, 74, 249, 111, 245, 135, 47, 127, 71, 33, 63, 6, 249, 231, 57, 112, 194, 244, 128, 250, 221, 53, 184, 185, 204, 3, 18, 240, 214, 108, 254, 218, 94, 93, 132, 133, 3, 79, 149, 135, 192, 160, 22, 226, 135, 103, 51, 26, 248, 24, 50, 189, 41, 82, 123, 125, 181])

        let t = AccountTransactionPayload.transferToPublic(SecToPubTransferData(serializedRemainingAmount: remainingAmount, transferAmount: transferAmount, index: index, serializedProof: proof))

        let expected = Data([18, 152, 42, 172, 135, 45, 247, 101, 240, 62, 167, 48, 72, 158, 57, 227, 117, 102, 82, 163, 65, 59, 215, 239, 167, 154, 88, 54, 99, 61, 17, 246, 44, 33, 224, 1, 251, 29, 115, 231, 200, 33, 248, 30, 116, 189, 205, 255, 205, 161, 32, 186, 235, 210, 21, 97, 88, 174, 247, 132, 24, 71, 255, 175, 166, 118, 180, 239, 152, 15, 32, 240, 239, 88, 194, 171, 175, 130, 168, 79, 83, 172, 41, 101, 149, 116, 243, 38, 79, 244, 203, 40, 138, 136, 38, 86, 21, 167, 124, 78, 40, 196, 63, 68, 82, 119, 153, 232, 152, 229, 135, 248, 7, 197, 245, 132, 60, 229, 14, 38, 199, 144, 42, 166, 66, 173, 205, 182, 78, 101, 23, 172, 253, 119, 245, 157, 110, 97, 69, 128, 33, 52, 55, 149, 78, 153, 219, 209, 88, 152, 222, 31, 186, 168, 175, 149, 119, 33, 67, 251, 74, 197, 192, 151, 200, 88, 25, 237, 16, 109, 85, 97, 130, 172, 145, 1, 163, 20, 9, 228, 213, 13, 160, 144, 193, 21, 33, 237, 145, 206, 161, 98, 187, 21, 220, 33, 6, 95, 210, 252, 41, 11, 125, 143, 108, 204, 213, 48, 27, 44, 6, 123, 161, 10, 55, 193, 218, 243, 86, 86, 47, 52, 225, 68, 174, 209, 79, 37, 35, 19, 85, 139, 89, 125, 71, 239, 195, 118, 28, 0, 79, 107, 61, 158, 206, 19, 77, 102, 10, 14, 112, 83, 231, 68, 46, 8, 162, 40, 46, 17, 158, 72, 52, 159, 184, 206, 81, 22, 79, 165, 34, 31, 193, 0, 0, 0, 1, 108, 249, 82, 182, 203, 100, 13, 191, 169, 82, 88, 51, 133, 204, 63, 252, 185, 213, 242, 237, 83, 56, 234, 88, 155, 95, 39, 210, 164, 23, 250, 99, 57, 226, 161, 244, 221, 118, 67, 74, 38, 157, 81, 179, 27, 232, 207, 27, 18, 173, 83, 128, 36, 208, 10, 170, 87, 114, 84, 240, 100, 196, 245, 137, 0, 0, 0, 2, 40, 195, 133, 183, 176, 103, 51, 44, 48, 86, 216, 230, 4, 217, 132, 121, 179, 19, 189, 172, 209, 20, 36, 179, 182, 82, 47, 4, 252, 155, 87, 32, 34, 209, 21, 46, 249, 4, 103, 142, 94, 16, 196, 2, 173, 228, 76, 201, 60, 191, 161, 187, 194, 66, 71, 49, 16, 101, 253, 150, 16, 129, 135, 235, 73, 243, 165, 139, 75, 227, 45, 145, 14, 157, 205, 102, 48, 94, 17, 132, 144, 209, 254, 115, 157, 76, 245, 99, 50, 41, 213, 229, 121, 49, 109, 56, 103, 10, 98, 24, 245, 130, 140, 227, 81, 158, 67, 251, 40, 238, 235, 67, 153, 100, 61, 91, 235, 2, 249, 229, 126, 64, 103, 32, 228, 58, 115, 218, 135, 31, 229, 166, 211, 13, 152, 223, 182, 20, 206, 229, 105, 252, 222, 108, 67, 139, 27, 224, 64, 214, 18, 135, 119, 22, 125, 58, 179, 87, 13, 166, 67, 70, 34, 167, 169, 177, 42, 120, 50, 140, 97, 66, 103, 142, 215, 60, 130, 94, 139, 49, 33, 65, 184, 5, 88, 72, 200, 222, 148, 63, 249, 244, 186, 122, 70, 241, 36, 50, 144, 94, 127, 96, 12, 211, 20, 154, 140, 244, 134, 249, 106, 240, 5, 3, 6, 47, 1, 81, 155, 196, 185, 14, 177, 113, 141, 156, 87, 234, 145, 149, 1, 197, 34, 138, 189, 177, 194, 45, 238, 195, 154, 162, 233, 255, 167, 0, 188, 177, 128, 0, 128, 161, 169, 112, 223, 255, 70, 143, 249, 14, 150, 128, 218, 9, 41, 59, 165, 163, 237, 59, 71, 135, 138, 245, 160, 56, 193, 52, 222, 207, 152, 216, 145, 255, 161, 175, 150, 139, 38, 167, 116, 23, 247, 59, 34, 192, 24, 52, 77, 246, 113, 93, 73, 51, 24, 17, 74, 75, 13, 34, 134, 67, 123, 77, 151, 111, 5, 223, 140, 117, 64, 210, 209, 91, 150, 239, 11, 145, 175, 51, 146, 33, 213, 161, 189, 27, 6, 21, 90, 138, 191, 72, 3, 31, 25, 85, 162, 19, 86, 15, 100, 182, 82, 117, 78, 22, 200, 33, 176, 36, 137, 58, 147, 139, 157, 127, 159, 143, 206, 102, 194, 178, 193, 149, 136, 47, 68, 243, 71, 219, 189, 123, 155, 2, 56, 182, 21, 49, 32, 19, 158, 6, 116, 149, 97, 145, 133, 119, 127, 72, 226, 97, 99, 176, 191, 92, 254, 154, 210, 123, 42, 223, 173, 19, 79, 38, 0, 0, 0, 6, 132, 57, 77, 169, 163, 225, 41, 244, 118, 130, 25, 135, 181, 155, 101, 8, 12, 123, 19, 59, 167, 141, 3, 46, 87, 158, 63, 38, 157, 14, 192, 133, 60, 21, 101, 211, 204, 31, 218, 64, 174, 23, 251, 177, 214, 170, 93, 24, 172, 237, 210, 198, 177, 70, 111, 90, 91, 232, 65, 130, 140, 192, 186, 209, 158, 85, 29, 111, 136, 4, 107, 220, 185, 125, 149, 107, 213, 233, 59, 124, 44, 148, 41, 117, 32, 234, 49, 247, 10, 73, 46, 197, 157, 6, 104, 184, 171, 191, 10, 157, 191, 172, 72, 97, 96, 27, 134, 127, 117, 41, 6, 231, 153, 229, 251, 115, 103, 119, 137, 11, 24, 101, 235, 174, 174, 8, 31, 113, 15, 203, 166, 57, 160, 190, 31, 11, 98, 240, 205, 187, 102, 133, 100, 147, 163, 50, 163, 68, 219, 197, 11, 242, 89, 207, 114, 22, 153, 151, 119, 249, 60, 39, 108, 182, 134, 187, 166, 161, 156, 13, 146, 190, 166, 106, 83, 172, 59, 214, 227, 71, 69, 188, 13, 175, 13, 98, 143, 225, 240, 28, 41, 229, 150, 252, 126, 32, 36, 192, 243, 71, 34, 154, 189, 126, 231, 181, 136, 55, 14, 49, 225, 136, 45, 120, 66, 199, 169, 213, 137, 88, 104, 78, 255, 87, 28, 22, 147, 72, 167, 31, 75, 103, 85, 67, 1, 10, 18, 112, 151, 196, 130, 178, 42, 159, 241, 162, 85, 209, 93, 220, 42, 54, 72, 125, 32, 199, 115, 147, 87, 87, 222, 139, 33, 107, 150, 42, 236, 29, 194, 253, 104, 206, 253, 184, 6, 192, 184, 219, 188, 207, 254, 114, 175, 123, 133, 86, 121, 224, 164, 115, 244, 124, 43, 132, 18, 216, 252, 240, 47, 69, 215, 147, 69, 114, 28, 23, 74, 46, 101, 240, 237, 229, 36, 7, 50, 215, 105, 93, 92, 227, 38, 80, 43, 231, 50, 183, 134, 254, 85, 111, 83, 246, 241, 182, 135, 4, 162, 131, 163, 123, 41, 133, 249, 247, 83, 214, 240, 224, 175, 111, 139, 54, 155, 147, 132, 17, 234, 137, 188, 240, 251, 113, 223, 51, 139, 113, 59, 137, 71, 74, 19, 19, 14, 160, 142, 230, 187, 135, 243, 16, 99, 79, 198, 93, 185, 79, 123, 144, 70, 43, 37, 185, 54, 159, 145, 47, 234, 165, 18, 96, 149, 46, 90, 1, 137, 117, 176, 235, 205, 34, 191, 32, 133, 93, 53, 80, 110, 228, 239, 134, 132, 139, 179, 145, 189, 233, 200, 87, 246, 80, 194, 97, 143, 190, 232, 215, 247, 178, 246, 228, 123, 160, 192, 214, 61, 86, 201, 121, 195, 251, 117, 7, 87, 42, 64, 113, 252, 127, 1, 207, 167, 6, 216, 95, 36, 20, 160, 191, 254, 95, 58, 162, 22, 67, 87, 235, 120, 34, 202, 245, 165, 42, 172, 65, 139, 182, 242, 57, 76, 54, 219, 64, 122, 43, 23, 98, 196, 100, 129, 132, 2, 86, 221, 195, 83, 222, 22, 84, 130, 213, 19, 179, 172, 109, 1, 250, 211, 42, 154, 156, 224, 189, 76, 0, 132, 250, 33, 140, 176, 119, 4, 153, 121, 180, 39, 85, 75, 178, 170, 25, 229, 69, 171, 140, 46, 177, 249, 163, 132, 165, 45, 208, 109, 225, 190, 206, 252, 172, 124, 164, 180, 133, 226, 121, 112, 64, 108, 131, 200, 47, 115, 106, 13, 19, 136, 162, 46, 55, 65, 136, 80, 100, 228, 176, 74, 249, 111, 245, 135, 47, 127, 71, 33, 63, 6, 249, 231, 57, 112, 194, 244, 128, 250, 221, 53, 184, 185, 204, 3, 18, 240, 214, 108, 254, 218, 94, 93, 132, 133, 3, 79, 149, 135, 192, 160, 22, 226, 135, 103, 51, 26, 248, 24, 50, 189, 41, 82, 123, 125, 181])

        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testUpdateCredentialKeysSerialization() throws {
        let credId = try CredentialRegistrationID(Data(hex: "a5727a5f217a0abaa6bba7f6037478051a49d5011e045eb0d86fce393e0c7b4a96382c60e09a489ebb6d800dc0d88d05"))
        let keys = try CredentialPublicKeys(keys: [2: VerifyKey(ed25519KeyHex: "d684ac5fd786d33c82701ce9f05017bb6f3114bec77c0e836e7d5c211de9acc6")], threshold: 1)
        let t = AccountTransactionPayload.updateCredentialKeys(credId: credId, keys: keys)

        let expected = Data([13, 165, 114, 122, 95, 33, 122, 10, 186, 166, 187, 167, 246, 3, 116, 120, 5, 26, 73, 213, 1, 30, 4, 94, 176, 216, 111, 206, 57, 62, 12, 123, 74, 150, 56, 44, 96, 224, 154, 72, 158, 187, 109, 128, 13, 192, 216, 141, 5, 1, 2, 0, 214, 132, 172, 95, 215, 134, 211, 60, 130, 112, 28, 233, 240, 80, 23, 187, 111, 49, 20, 190, 199, 124, 14, 131, 110, 125, 92, 33, 29, 233, 172, 198, 1])
        XCTAssertEqual(t.serialize(), expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testCanCreateBakerKeys() throws {
        let account = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        let bakerKeys = BakerKeyPairs.generate()
        let _ = try BakerKeysPayload.create(account: account, bakerKeys: bakerKeys)
    }

    // func testUpdateCredentialsSerialization() throws { } FIXME: implement

    func testConfigureBakerSerialization() throws {
        let signatureVerifyKey = Data([247, 193, 33, 152, 127, 222, 9, 217, 38, 58, 30, 84, 214, 143, 194, 7, 99, 168, 111, 194, 57, 149, 108, 94, 213, 206, 244, 99, 39, 250, 108, 93])
        let electionVerifyKey = Data([178, 57, 219, 237, 5, 241, 101, 120, 212, 13, 95, 125, 88, 119, 48, 215, 9, 86, 181, 4, 19, 87, 54, 192, 17, 84, 235, 124, 93, 101, 169, 78])
        let aggregationVerifyKey = Data([143, 45, 244, 130, 96, 225, 106, 28, 201, 134, 86, 84, 95, 62, 163, 1, 26, 240, 3, 61, 241, 213, 198, 87, 176, 234, 21, 240, 32, 248, 213, 239, 34, 193, 121, 239, 93, 202, 57, 75, 27, 180, 52, 230, 190, 19, 38, 18, 22, 249, 92, 162, 5, 83, 200, 245, 148, 43, 159, 232, 209, 72, 23, 178, 211, 210, 39, 158, 205, 134, 232, 140, 127, 223, 78, 70, 133, 4, 76, 203, 48, 115, 131, 246, 253, 203, 206, 115, 225, 38, 81, 105, 166, 67, 220, 71])
        let proofSig = Data([11, 46, 77, 245, 199, 21, 221, 29, 36, 155, 150, 134, 175, 125, 228, 250, 50, 134, 139, 206, 247, 34, 22, 118, 31, 234, 52, 119, 189, 114, 32, 3, 125, 136, 124, 125, 155, 6, 157, 158, 197, 165, 70, 242, 183, 234, 149, 120, 232, 2, 141, 155, 172, 142, 221, 133, 62, 71, 34, 70, 19, 144, 175, 14])
        let proofElection = Data([82, 121, 251, 107, 209, 88, 161, 195, 131, 16, 188, 8, 13, 5, 79, 234, 127, 109, 72, 174, 205, 208, 165, 199, 138, 42, 59, 40, 122, 145, 221, 14, 218, 49, 39, 170, 5, 6, 239, 142, 193, 106, 33, 233, 44, 230, 218, 187, 63, 42, 72, 190, 147, 18, 240, 29, 29, 45, 105, 182, 146, 170, 146, 5])
        let proofAggregation = Data([132, 244, 27, 33, 127, 164, 95, 185, 214, 199, 185, 237, 77, 222, 159, 109, 227, 127, 52, 32, 197, 90, 185, 46, 25, 239, 228, 177, 220, 107, 236, 186, 9, 91, 230, 208, 101, 197, 217, 133, 68, 88, 65, 31, 116, 97, 191, 177, 108, 162, 188, 56, 165, 120, 133, 230, 138, 98, 129, 199, 205, 149, 163, 194])

        let capital: MicroCCDAmount = 1_234_567
        let restakeEarnings = true
        let openForDelegation = OpenStatus.closedForAll
        let metadataUrl = "https://url.com/test"
        let keysWithProofs = BakerKeysPayload(signatureVerifyKey: signatureVerifyKey, electionVerifyKey: electionVerifyKey, aggregationVerifyKey: aggregationVerifyKey, proofSig: proofSig, proofElection: proofElection, proofAggregation: proofAggregation)
        let tfCommission = AmountFraction(partsPerHundredThousand: 4321)
        let brCommission = AmountFraction(partsPerHundredThousand: 6545)
        let frCommission = AmountFraction(partsPerHundredThousand: 18989)

        var data = ConfigureBakerPayload()
        var t = AccountTransactionPayload.configureBaker(data)

        var expected = Data([25, 0, 0])
        var actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureBakerPayload(capital: capital)
        t = AccountTransactionPayload.configureBaker(data)

        expected = Data([25, 0, 1, 0, 0, 0, 0, 0, 18, 214, 135])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureBakerPayload(restakeEarnings: restakeEarnings)
        t = AccountTransactionPayload.configureBaker(data)

        expected = Data([25, 0, 2, 1])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureBakerPayload(metadataUrl: metadataUrl)
        t = AccountTransactionPayload.configureBaker(data)

        expected = Data([25, 0, 16, 0, 20, 104, 116, 116, 112, 115, 58, 47, 47, 117, 114, 108, 46, 99, 111, 109, 47, 116, 101, 115, 116])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureBakerPayload(capital: capital, restakeEarnings: restakeEarnings, openForDelegation: openForDelegation, keysWithProofs: keysWithProofs, metadataUrl: metadataUrl, transactionFeeCommission: tfCommission, bakingRewardCommission: brCommission, finalizationRewardCommission: frCommission)
        t = AccountTransactionPayload.configureBaker(data)

        expected = Data([25, 0, 255, 0, 0, 0, 0, 0, 18, 214, 135, 1, 2, 178, 57, 219, 237, 5, 241, 101, 120, 212, 13, 95, 125, 88, 119, 48, 215, 9, 86, 181, 4, 19, 87, 54, 192, 17, 84, 235, 124, 93, 101, 169, 78, 82, 121, 251, 107, 209, 88, 161, 195, 131, 16, 188, 8, 13, 5, 79, 234, 127, 109, 72, 174, 205, 208, 165, 199, 138, 42, 59, 40, 122, 145, 221, 14, 218, 49, 39, 170, 5, 6, 239, 142, 193, 106, 33, 233, 44, 230, 218, 187, 63, 42, 72, 190, 147, 18, 240, 29, 29, 45, 105, 182, 146, 170, 146, 5, 247, 193, 33, 152, 127, 222, 9, 217, 38, 58, 30, 84, 214, 143, 194, 7, 99, 168, 111, 194, 57, 149, 108, 94, 213, 206, 244, 99, 39, 250, 108, 93, 11, 46, 77, 245, 199, 21, 221, 29, 36, 155, 150, 134, 175, 125, 228, 250, 50, 134, 139, 206, 247, 34, 22, 118, 31, 234, 52, 119, 189, 114, 32, 3, 125, 136, 124, 125, 155, 6, 157, 158, 197, 165, 70, 242, 183, 234, 149, 120, 232, 2, 141, 155, 172, 142, 221, 133, 62, 71, 34, 70, 19, 144, 175, 14, 143, 45, 244, 130, 96, 225, 106, 28, 201, 134, 86, 84, 95, 62, 163, 1, 26, 240, 3, 61, 241, 213, 198, 87, 176, 234, 21, 240, 32, 248, 213, 239, 34, 193, 121, 239, 93, 202, 57, 75, 27, 180, 52, 230, 190, 19, 38, 18, 22, 249, 92, 162, 5, 83, 200, 245, 148, 43, 159, 232, 209, 72, 23, 178, 211, 210, 39, 158, 205, 134, 232, 140, 127, 223, 78, 70, 133, 4, 76, 203, 48, 115, 131, 246, 253, 203, 206, 115, 225, 38, 81, 105, 166, 67, 220, 71, 132, 244, 27, 33, 127, 164, 95, 185, 214, 199, 185, 237, 77, 222, 159, 109, 227, 127, 52, 32, 197, 90, 185, 46, 25, 239, 228, 177, 220, 107, 236, 186, 9, 91, 230, 208, 101, 197, 217, 133, 68, 88, 65, 31, 116, 97, 191, 177, 108, 162, 188, 56, 165, 120, 133, 230, 138, 98, 129, 199, 205, 149, 163, 194, 0, 20, 104, 116, 116, 112, 115, 58, 47, 47, 117, 114, 108, 46, 99, 111, 109, 47, 116, 101, 115, 116, 0, 0, 16, 225, 0, 0, 25, 145, 0, 0, 74, 45])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testConfigureDelegationSerialization() throws {
        var data = ConfigureDelegationPayload(capital: 12_000_000, delegationTarget: DelegationTarget.passive)
        var t = AccountTransactionPayload.configureDelegation(data)

        var expected = Data([26, 0, 5, 0, 0, 0, 0, 0, 183, 27, 0, 0])
        var actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureDelegationPayload(delegationTarget: DelegationTarget.baker(1234))
        t = AccountTransactionPayload.configureDelegation(data)

        expected = Data([26, 0, 4, 1, 0, 0, 0, 0, 0, 0, 4, 210])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureDelegationPayload(capital: 432, restakeEarnings: true, delegationTarget: DelegationTarget.baker(12))
        t = AccountTransactionPayload.configureDelegation(data)

        expected = Data([26, 0, 7, 0, 0, 0, 0, 0, 0, 1, 176, 1, 1, 0, 0, 0, 0, 0, 0, 0, 12])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)

        data = ConfigureDelegationPayload()
        t = AccountTransactionPayload.configureDelegation(data)

        expected = Data([26, 0, 0])
        actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }
}
