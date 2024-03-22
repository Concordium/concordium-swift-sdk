import ConcordiumWalletCrypto
import Foundation
import GRPC
import NIOCore
import NIOPosix

public protocol NodeClientProtocol {
    func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters
    func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber
    func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo
}

public class GrpcNodeClient: NodeClientProtocol {
    let grpc: Concordium_V2_QueriesClientProtocol

    init(_ grpc: Concordium_V2_QueriesClientProtocol) {
        self.grpc = grpc
    }

    public convenience init(channel: GRPCChannel) {
        self.init(Concordium_V2_QueriesNIOClient(channel: channel))
    }

    public func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters {
        let req = block.toGrpcType()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return .fromGrpcType(res)
    }

    public func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address.data
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return .fromGrpcType(res)
    }

    public func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGrpcType()
        req.blockHash = block.toGrpcType()
        let res = try await grpc.getAccountInfo(req).response.get()
        return try .fromGrpcType(res)
    }
}
