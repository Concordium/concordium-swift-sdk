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

    func testUpdateCredentialsSerialization() throws {
        let credJson = """
        {
        "credentialPublicKeys": {
        "keys": {
            "0": {
                "schemeId": "Ed25519",
                "verifyKey": "d684ac5fd786d33c82701ce9f05017bb6f3114bec77c0e836e7d5c211de9acc6"
            },
            "1": {
                "schemeId": "Ed25519",
                "verifyKey": "df70d598d7cf8954b7b6d27bee2b94c4f2f5540219573bca70600c7cde39e92d"
            },
            "2": {
                "schemeId": "Ed25519",
                "verifyKey": "6f2da81a8f7d6965d720527d31c05efdb197129ed54fee51500b2c1742b3a43a"
            }
        },
        "threshold": 2
        },
        "credId": "a5727a5f217a0abaa6bba7f6037478051a49d5011e045eb0d86fce393e0c7b4a96382c60e09a489ebb6d800dc0d88d05",
        "commitments": {
        "cmmPrf": "abcdef",
        "cmmCredCounter": "2",
        "cmmIdCredSecSharingCoeff": ["1", "2", "3", "4", "5"],
        "cmmAttributes": {},
        "cmmMaxAccounts": "3"
        },
        "ipIdentity": 0,
        "revocationThreshold": 5,
        "arData": {
        "1": {
            "encIdCredPubShare": "a458d29cdf02ae34d2ae9b11da12a20df1cb2f0051f50547ca975c1916334443f8654198ffd55763274d7663b3f71def89950e178445b2c080de77cbe66bf16716808124af92b99f4d042568a8ac178a51050b04c073e5400a8e89dce61290fd"
        },
        "2": {
            "encIdCredPubShare": "b84f64cb45ff97d96380dd94324c99f850bcde2cb16eefade2775b2cf0f8183349766468a2ee0f855aa6b7beb585967fa798439b0e02a3181b5b27b22ec4926b1927d4b4c81c6a2dd7e1c850c902c1e3a4d730b0af41ca522d5ccb613416a64f"
        },
        "3": {
            "encIdCredPubShare": "944c9009adfecee0ad2cf613b73b80a28228e1e1daf6f0d7a7e3d35bc88d18c267835b3e47fc01afc1d51f8639a4cad48aed53c2630f015b9b8eddda5fd93f5856da962456edd05c3a70d4bccf75a552cc0ec4edd65afd7eb526264edb5ff884"
        },
        "4": {
            "encIdCredPubShare": "a6d8667d09800553890d8f285454825d277c42d55e96ed11774939d333059e63ae5fc72ef6fefbc81c65fa37b1e3763a8b2cef934b1d2ddfd26f8227a074204e3343a4dcd3e17f88838964c30adfeb9b00b12973627178fac4aeb88771d30510"
        },
        "5": {
            "encIdCredPubShare": "a4f83b6ec95ca1417aa3a90f6108916b10bdbec85a514655f142ed38b02760364246510be006d7d001cc6c6c839bae72899c10ad29ca8feb171330feacf066c88f3b9617ce99ea44e56be8c57b50ea1865ba73585012bbc8b1035e0c73fb557c"
        }
        },
        "policy": {
        "validTo": "202205",
        "createdAt": "202005",
        "revealedAttributes": {
            "lastName": "31"
        }
        },
        "proofs": "8de04f30f49ae527b47849db1b47ce552d7418b80db2cba081fdf3633d5603447ae7ec23d9f7dc1cf5ab1d6b3cdffac396ee4c6c4729fc3f1e9522106aa1ba8c4f520a7723cdb448a0a173e6303668856059fbc451c2e0fad097bea790495141a2777040540cebb08c901d1e6f02558b066270a386f37d1c5e2bc43d9993ddaae856ea4c797dd6a87c2492099e644de98dc05433eedcbb889836585c219c4511e15a0ccd482ce13a6dcf3925972bedc57d39ce7c66dd3f543e2fe6a56c162c28b8787bf461820596b23eee6c8eeccc9033e0a58131680e27eff1abe79335cd839335607ab92da5c59108d4f40d8d550e00010081b4666e437108d43118aa99b49ffd1d0c0ae50582c98ea8e579dcd7915766affc1b7f43c6eacf7f3cb4a5277f364ddf000000000000000581d0c77cfd5d4a2cad61af4e297c3758e9b124e795175f6a38df4359b4a3fdb72a1425b4f3b24c506d3ec1b01f88e9c6b8a09102d73cb8595dd6451b379ea10c448af16240bbb9f17dbdc82cc618b502804ecfae627b1b98dca9caf9f6e58877a42ceb77aec5b8f23b23e1964972a91b7a7a2ba3a26f988b5a8d9686e322be424263a5d7633fcf0bd6c08c01b1ed56c591a5de15fdd9615adea505ce5826ea856cd416d9d9d7cbffa9707b29767d3d828546d0d70dc65548e4f7ebc137161a06a5c244cec74ac7532dfae1a55d6f72b17183cdac5efb6dadb05b5fa9190886cd22dab6af2c529b78c94f172614fb4566fd0a40d21729a8dc162172b391a016010663a8d218e0a2619e3c1078e350171d000000050000000156f626c9797ba29d4f25d0e3fb13bf123fafa0fddd1904e00f8bfbcd58a21d88271593d2ec15a4a5f221e5cb323affe74d3b2fb079d9383e51e4d28a3974909c25f89d29e7d46a0be7d53d06419ecaa25a7d5a0709cc4042530b7a786fcf059f00000002264be8a2a42bc92545f2b3097245c32d73f9af158b2043149ad11dccd18a3e2866a07ff991d62b4e1095e4a38886e039920515645225a4cc7ed1a95dc441c8452b4ba0c6ddd22b18bda5f8f95de768b363c06be021bbd2b3866c19033b07544a00000003264fc3e92b8b4fb305e2ae4fd489185c0b2db6f17fee2b8322a4d616bc6bbdc5646354ab202cca69f8e048818fc1a7cca118c4c781e48717a74a9722b9808d3a396aeba5b3a202c70b80069f49e90abfd8c273f907ed152deef3ca94d152c0ba000000041e7beb80ce73f7cb51af2c7f88343a9034ccd3c9016864a54e53ce62bcb228fc6b0130690cc2f6464b6f15bd46ca1a14a771f9295dc159f1751efc854b112d38704682a1e69833de7d1dcd897530b95425c64a047da9c2eec8f378371e89ac1c0000000512e0ae9fec6bc90a82f401d873d166d37af6c7036fa0e4b7bb165bfb51793a1d31b2ba053a4f1033ce2fba48b5fb9627bfbc54b6b80e4a12f5dad6b5c9a69be21c66db79ea672b27e769417f0580981eb74270588af4d168cb55d35ec07cad5c6371eb5ae9ebcf2e6dc3528e2c23ee60f8457cf0a7ad37ac8a0738a7024154a8000000080757f2f50fbc24693d6123840db7816b061625b5db543cf2dfa0ed97d6a4580f080031487225c5a4c6f8137c6ed22b62e3c7147208335d44e8960a731ee9d9281e36dd40960ff56e1d9f1c6b5a113b2ad7273a13d436a0c907723160d3dd583822ca004f5aa5baed781f60fd517a52476aa1418179cdef8be6e9008b39600864319e1726df94f871aee2503e58b550754857e103c11e61088e2832071d77aae86d910bac00430c87d49fb8fbc1772c380accf943ed7ce8027b7082bc1c0ab96701744a37de324ace32d012eead95938a82a0a5e13100a02e3d3018b7dc30ea9b5ef9a53397eaa75097c94496dff9cc7f4a3306bcb2109add64308f8f0dce7863729995d755f16982168cfd8da56b6d8372a92c1b66dc5e473f20f2cca797cb0021755fb84d154d906dd024909af27df61eba71956790dba63e05d53d3dda18cc164a847e6ea7c85d5bb098a9700fbbe44a14c0ad3740d8676bdf5f658ba833fe2581d28265a98699a42fcc64f0af2594d8de352f169cdef7f9676ede3e29ceb3273329f3141432a0f82fc21b9962886bdf03bcd7c08edf916f7729c83f8dc1af6dbc8baa1999977e65462802c6e079797c8f8a856ed318c140e9d158adc8a7af03bab3027f4c5f38459ad8bee1ca254a05b8e0fc3f3362d0a37230d981ee1dbf505177c36e4cec2c28f25cee5f58b995aa4ae9814ec6dbd8eeaffface9b784ea6c37c4556f98ca84dc87a2aa02c686d624a96897a48146ee84ea7053414685c83e2d054d819295eb2fa7deaebbcce36bd5d0bf616a24027139bd535a87fd6d05541fa7241c2faba915b9efec6f8e18e1aeac96c51f29fdf47297a8dda26624015fa7bbce725d73c6fbfcd992270459e42a4e8c10ecf98c1cb8e92b49588db0ee3c672f0419b96b90bce28005e8ce61ef12db46ea28bf78e069e2906009b836fc03005ff4b9177d0ca17945439c9cbab5c8925b1dee3fcc3f38bf531972c27ca12e2f9f63d10e202dd3d4133e841ff4d18f85699d093be56b420494a16990a005130b016f8c01ece174d5513e67a843388c60a254d720c989fafc3aca223259b78f32159f26539236c7b7f41bc7bac0b705c645a316af1a35542e60b10e668a03881e0f02167738c36bbadd7f2b9ecce6bceea81c2f66c87417e001037d86a20dd592201e2a5e8432d47ea459f5025725a09e2f7d13a5876cb8fc83c6cfd67b143a305204a830c829dbbb57a14dd16ccadfbd2931765e77b75e21050d7a12cb7e3c18e293eb4eb8eb6f347a533231e7f779f635c08baba6971ed89b35c764f3c4c2cc791cc9fc6515a9d0fb4f32d61ce8e553a4d29c24125515885a6ea38446f26011da81a157b898a914542bd13102dc32fef0045d88dfccbff7b8614b35c95e6db61e96d37a22f685d6f5a58173ef1c9d70fce0883dc84609835d57ac8015ba8bdcc62b24fe8c66097a0cfadd4acb90334d03d6b8e47287670dc1bff24563df60aea1cf62d05dad3da072d19b6b15d2f60d5f678652a871a15e5c7cf1424fe0140d3b4772849b099a36c46135fdf1bc54e07871dcfe3cbd84ec5e815ecaa9dc698442506d2bffa7fe29b5de209d8bdebb91ee036c45b44beb7abd6694b15b5f1daa4fd900000004893d20bff691738bc05d5f64ec440ba1b5230a745cd5a1aba5ea5c825fb6c3207cf7c9031b2e0973f71def0c8bd6b6deb31d25df2c11c98d4971c61d74ad9d775b78459bf53f90ca5cf022d79b229a7193a1d8553bab369539bfdfd48979778c86bf2d3dfa160aecab9d2c25b8234a9142393edbc22b13eff31014671f22d33482ed69b305ecb3fcaac42785c4fe5bc496d920d1c56d7c37fb706874c142be02f884955bdedf1d55f810ada375d6d159ec14d4afbc20a4d102f694fb0df8993a8954b5794d6a9674faac3c34d29c893d8fb1fde8f7edfc023a77668dc48d3c7217d2dcc1b3f22609668752f9bebf970d880948ffd35831fa9f6745cc5cc181fb93acf110d05453fd5dcf9d71c052bf8ff2bf9bed978a4afe50bc35de97afb83cb813d25c06794f7c7450c296df24985dda1e7a74eb8e3357bb2582444b54a986cfebde872b47dd83def6f21c736365b7a6184ec3040caa8184ee3dcd05b4cb75d6bc0c159647a59bd26a3ac193b571bd9261c8241ca5d529eab45abd725a8e9d5dea08a4b504b8d0ae5a398f270555e24c013350f77467b2186f3c775b1396a1434f6ec4cf51fa5c6ee8688c6e4c73ec67f1be9c742d3c6ab1c916159191d741"
        }

        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let cred = try decoder.decode(CredentialDeploymentInfo.self, from: credJson)
        let newCredInfos = [0 as UInt32: cred]
        let credId = try CredentialRegistrationID(Data(hex: "a5727a5f217a0abaa6bba7f6037478051a49d5011e045eb0d86fce393e0c7b4a96382c60e09a489ebb6d800dc0d88d05"))

        let t = AccountTransactionPayload.updateCredentials(newCredInfos: newCredInfos, removeCredIds: [credId], newThreshold: 5)
        let expected = Data([25, 0, 0])
        let actual = t.serialize()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(AccountTransactionPayload.deserialize(expected), t)
    }

    func testCanCreateBakerKeys() throws {
        let account = try AccountAddress(base58Check: "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh")
        let bakerKeys = BakerKeyPairs.generate()
        let _ = try BakerKeysPayload.create(account: account, bakerKeys: bakerKeys)
    }

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
