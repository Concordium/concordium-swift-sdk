import BigInt
import Foundation
import XCTest
@testable import Concordium

final class PLTTransactionCostTests: XCTestCase {
    func testTransferOperationBaseCost() {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_000_000), decimals: 6)
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let operation = TokenUpdateOperation.transfer(payload)

        XCTAssertEqual(operation.baseCost, Energy(100))
    }

    func testTokenUpdateOperationsBaseCost() {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_000_000), decimals: 6)
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let operation = TokenUpdateOperation.transfer(payload)

        let tokenUpdate = TokenUpdate(tokenSymbol: "TEST", operations: [operation])

        XCTAssertEqual(tokenUpdate.getOperationsBaseCost(), Energy(100))
    }

    func testPLTTransferCostCalculation() {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_000_000), decimals: 6)
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )
        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let operation = TokenUpdateOperation.transfer(payload)
        let cost = TransactionCost.pltTransferCost(tokenId: "TEST", operation: operation)

        // Should be base cost + operations cost
        let expectedOperationsCost = Energy(100)
        let actualPayload = AccountTransactionPayload.updatePLT(tokenId: "TEST", operation: operation)
        let actualPayloadSize = actualPayload.serialize().count
        let expectedBaseCost = TransactionCost.base(headerByteCount: 0, payloadByteCount: actualPayloadSize, signatureCount: 1)
        let expectedTotalCost = expectedBaseCost + expectedOperationsCost

        XCTAssertEqual(cost, expectedTotalCost)
        XCTAssertGreaterThan(cost, Energy(0))
    }

    func testPLTTransferCostWithMemo() {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_000_000), decimals: 6)
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )
        let memo = PLT.CborMemo(string: "Test memo")

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver, memo: memo)
        let operation = TokenUpdateOperation.transfer(payload)

        let cost = TransactionCost.pltTransferCost(tokenId: "TEST", operation: operation)

        // Should be base cost + operations cost (memo affects payload size)
        let expectedOperationsCost = Energy(100)
        let actualPayload = AccountTransactionPayload.updatePLT(tokenId: "TEST", operation: operation)
        let actualPayloadSize = actualPayload.serialize().count
        let expectedBaseCost = TransactionCost.base(headerByteCount: 0, payloadByteCount: actualPayloadSize, signatureCount: 1)
        let expectedTotalCost = expectedBaseCost + expectedOperationsCost

        XCTAssertEqual(cost, expectedTotalCost)
    }

    func testPLTTransferCostWithDifferentTokenIds() {
        let amount = PLT.TokenOperationAmount(value: BigUInt(1_000_000), decimals: 6)
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let payload = ConfigureTransferPLTPayload(amount: amount, receiver: receiver)
        let operation = TokenUpdateOperation.transfer(payload)

        let cost1 = TransactionCost.pltTransferCost(tokenId: "SHORT", operation: operation)
        let cost2 = TransactionCost.pltTransferCost(tokenId: "VERYLONGTOKENID", operation: operation)

        // Longer token ID should result in higher cost due to larger payload
        XCTAssertGreaterThan(cost2, cost1)
    }

    func testPLTTransferCostWithDifferentAmounts() {
        let receiverData = try! Data(hex: "21bc8745c81c07ca7f3fb79a8bd161624cb1d5da788baec13f5a5d9eac3a29b7")
        let receiver = PLT.TaggedTokenHolderAccount(
            accountAddress: PLT.AccountAddress(data: receiverData)
        )

        let amount1 = PLT.TokenOperationAmount(value: BigUInt(1), decimals: 2)
        let amount2 = PLT.TokenOperationAmount(value: BigUInt(1_000_000_000_000), decimals: 12)

        let payload1 = ConfigureTransferPLTPayload(amount: amount1, receiver: receiver)
        let payload2 = ConfigureTransferPLTPayload(amount: amount2, receiver: receiver)

        let operation1 = TokenUpdateOperation.transfer(payload1)
        let operation2 = TokenUpdateOperation.transfer(payload2)

        let cost1 = TransactionCost.pltTransferCost(tokenId: "TEST", operation: operation1)
        let cost2 = TransactionCost.pltTransferCost(tokenId: "TEST", operation: operation2)

        // Different amounts should result in different costs due to different payload sizes
        XCTAssertNotEqual(cost1, cost2)
    }
}
