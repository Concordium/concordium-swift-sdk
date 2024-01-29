import CryptoKit
import Foundation
import GRPC
import NIOCore
import NIOPosix

public protocol ConcordiumNodeClient {
    func getCryptographicParameters(at block: BlockIdentifier) async throws -> CryptographicParameters

    func getNextAccountSequenceNumber(of address: AccountAddress) async throws -> NextAccountSequenceNumber

    func getAccountInfo(of account: AccountIdentifier, at block: BlockIdentifier) async throws -> AccountInfo
}

public class ConcordiumNodeGrpcClient: ConcordiumNodeClient {
    let grpc: Concordium_V2_QueriesClientProtocol

    init(_ grpc: Concordium_V2_QueriesClientProtocol) {
        self.grpc = grpc
    }

    public convenience init(channel: GRPCChannel) {
        self.init(Concordium_V2_QueriesNIOClient(channel: channel))
    }

    public func getCryptographicParameters(at block: BlockIdentifier) async throws -> CryptographicParameters {
        let req = block.toGrpcType()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return .fromGrpcType(res)
    }

    public func getNextAccountSequenceNumber(of address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address.bytes
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return .fromGrpcType(res)
    }

    public func getAccountInfo(of account: AccountIdentifier, at block: BlockIdentifier) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGrpcType()
        req.blockHash = block.toGrpcType()
        let res = try await grpc.getAccountInfo(req).response.get()
        return try .fromGrpcType(res)
    }

    public func sendSimpleTransfer(from sender: AccountAddress, to receiver: AccountAddress, microCcdAmount: MicroCcdAmount, sequenceNumber: SequenceNumber, privateKey: Curve25519.Signing.PrivateKey) async throws -> TransactionHash {
        let fiveMinutesLaterMs = UInt64(Calendar.current.date(byAdding: .minute, value: 5, to: Date())!.timeIntervalSince1970 * 1000)
        let header = AccountTransactionHeader(sender: sender, sequenceNumber: sequenceNumber, energyAmount: TransactionTypeCost.transferBaseCost.value, expiry: fiveMinutesLaterMs)
        let payload = AccountTransactionPayload.transfer(microCcdAmount)

        return try await sendAccountTransaction(AccountTransaction(header: header, payload: payload))
    }

    public func sendAccountTransaction(_ accountTransaction: AccountTransaction) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        let res = try await grpc.sendBlockItem(req).response.get()
        return res.value
    }
}
