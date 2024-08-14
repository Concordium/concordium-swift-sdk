import Foundation
import GRPC
import NIOCore
import NIOPosix

public struct SubmittedTransaction {
    /// The hash of the submitted transaction
    public let hash: TransactionHash
    private let client: any NodeClient

    // TODO: implement...
    // public func waitUntilFinalized() throws -> (block: BlockHash, summary: BlockItemSummary) { }
}

public enum TransactionStatus {
    case received
    case committed(outcomes: [BlockHash: BlockItemSummary])
    case finalized(outcome: (blockHash: BlockHash, summary: BlockItemSummary))
}

extension TransactionStatus: FromGRPC {
    typealias GRPC = Concordium_V2_BlockItemStatus 

    static func fromGRPC(_ g: GRPC) throws -> TransactionStatus {
        guard let status = g.status else { throw GRPCError.missingRequiredValue("Expected 'status' to be available for 'BlockItemStatus'")}
        switch status {
        case .received(_):
            return .received
        case .committed(let data):
            let outcomes = try data.outcomes.reduce(into: [:]) { acc, block in 
                acc[try BlockHash.fromGRPC(block.blockHash)] = try BlockItemSummary.fromGRPC(block.outcome)
            }
            return .committed(outcomes: outcomes)
        case .finalized(let data):
            let blockHash = try BlockHash.fromGRPC(data.outcome.blockHash)
            let summary = try BlockItemSummary.fromGRPC(data.outcome.outcome)
            return .finalized(outcome: (blockHash: blockHash, summary: summary))
        }
    }
}

/// Protocol for Concordium node clients targetting the GRPC v2 API
public protocol NodeClient {
    /// Get the global context for the chain
    func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters
    /// Get the list of identity providers registered for the chain
    func identityProviders(block: BlockIdentifier) async throws -> [IdentityProviderInfo]
    /// Get the list of identity disclosure autorities registered for the chain
    func anonymityRevokers(block: BlockIdentifier) async throws -> [AnonymityRevokerInfo]
    /// Get the next account sequence number for the account
    func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber
    /// Get the account info for an account
    func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo
    /// Get the account info for a block
    func info(block: BlockIdentifier) async throws -> BlockInfo
    /// Submit a transaction to the node
    func send(transaction: SignedAccountTransaction) async throws -> TransactionHash
    /// Submit an account credential deployment to the node
    func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> TransactionHash
    /// Query the status of a transaction
    func status(transaction: TransactionHash) async throws -> TransactionStatus 
}

/// Error happening while constructing a ``NodeClient``
public struct NodeClientError: Error {
    public let message: String
}

/// Defines a GRPC client for communicating with the GRPC v2 API of a given Concordium node.
public class GRPCNodeClient: NodeClient {
    let grpc: Concordium_V2_QueriesClientProtocol

    init(_ grpc: Concordium_V2_QueriesClientProtocol) {
        self.grpc = grpc
    }

    /// Initialize a GRPC client from a URL.
    /// - Throws: ``NodeClientError`` if parsing scheme, host, or port from the supplied ``URL`` fails
    @available(macOS 13.0, *)
    public convenience init(url: URL) throws {
        guard let secure = url.scheme?.starts(with: "https") else { throw NodeClientError(message: "Missing url scheme") }
        guard let host = url.host() else { throw NodeClientError(message: "Failed to parse host from URL") }
        guard let port = url.port else { throw NodeClientError(message: "Failed to parse port from URL") }

        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        let builder = secure ? ClientConnection.usingPlatformAppropriateTLS(for: group) : ClientConnection.insecure(group: group)
        let connection = builder.connect(host: host, port: port)
        self.init(channel: connection)
    }

    /// Initialize a GRPC client from the supplied GRPC channel
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

    public func info(block: BlockIdentifier) async throws -> BlockInfo {
        let res = try await grpc.getBlockInfo(block.toGRPC()).response.get()
        return try .fromGRPC(res)
    }

    public func send(transaction: SignedAccountTransaction) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.accountTransaction = transaction.toGRPC()
        let res = try await grpc.sendBlockItem(req).response.get()
        return try .fromGRPC(res)
    }

    public func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.credentialDeployment = deployment.toGRPC()
        let res = try await grpc.sendBlockItem(req).response.get()
        return try .fromGRPC(res)
    }

    public func status(transaction: TransactionHash) async throws -> TransactionStatus {
        let res = try await grpc.getBlockItemStatus(transaction.toGRPC()).response.get()
        return try .fromGRPC(res)
    }
}
