import Foundation
import GRPC
import NIOCore
import NIOPosix

public protocol NodeClient {
    func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters
    func identityProviders(block: BlockIdentifier) async throws -> [IdentityProviderInfo]
    func anonymityRevokers(block: BlockIdentifier) async throws -> [AnonymityRevokerInfo]
    func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber
    func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo
    func send(transaction: SignedAccountTransaction) async throws -> TransactionHash
    func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> TransactionHash
}

public class GRPCNodeClient: NodeClient {
    let grpc: Concordium_V2_QueriesClientProtocol

    init(_ grpc: Concordium_V2_QueriesClientProtocol) {
        self.grpc = grpc
    }

    public convenience init(channel: GRPCChannel) {
        self.init(Concordium_V2_QueriesNIOClient(channel: channel))
    }

    public func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters {
        let req = block.toGRPC()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return .fromGRPC(res)
    }

    public func identityProviders(block: BlockIdentifier) async throws -> [IdentityProviderInfo] {
        let req = block.toGRPC()
        var res: [IdentityProviderInfo] = []
        let call = grpc.getIdentityProviders(req) {
            res.append(.fromGRPC($0))
        }
        _ = try await call.status.get()
        return res
    }

    public func anonymityRevokers(block: BlockIdentifier) async throws -> [AnonymityRevokerInfo] {
        let req = block.toGRPC()
        var res: [AnonymityRevokerInfo] = []
        let call = grpc.getAnonymityRevokers(req) {
            res.append(.fromGRPC($0))
        }
        _ = try await call.status.get()
        return res
    }

    public func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address.data
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return .fromGRPC(res)
    }

    public func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGRPC()
        req.blockHash = block.toGRPC()
        let res = try await grpc.getAccountInfo(req).response.get()
        return try .fromGRPC(res)
    }

    public func send(transaction: SignedAccountTransaction) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.accountTransaction = transaction.toGRPC()
        let res = try await grpc.sendBlockItem(req).response.get()
        return TransactionHash(value: res.value)
    }

    public func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.credentialDeployment = deployment.toGRPC()
        let res = try await grpc.sendBlockItem(req).response.get()
        return TransactionHash(value: res.value)
    }
}
