import Foundation
import GRPC
import NIOCore
import NIOPosix

/// Describes a transaction which has been submitted to a node.
public struct SubmittedTransaction {
    /// The hash of the submitted transaction
    public let hash: TransactionHash
    private let client: any NodeClient

    init(hash: TransactionHash, client: any NodeClient) {
        self.hash = hash
        self.client = client
    }

    /// Alias for ``NodeClient.waitUntilFinalized`` for the ``Self.hash``
    ///
    /// - Parameter timeoutSeconds: An optional timeout. It is recommended to supply this, as otherwise the function can run indefinitely.
    /// - Throws: ``TimeoutError`` if the supplied timeout is hit before the transaction has been finalized in a block
    /// - Returns: ``(blockHash: BlockHash, summary: BlockItemSummary)`` when the transaction has been finalized
    public func waitUntilFinalized(timeoutSeconds: UInt? = nil) async throws -> (blockHash: BlockHash, summary: BlockItemSummary) {
        try await client.waitUntilFinalized(transaction: hash, timeoutSeconds: timeoutSeconds)
    }

    /// Alias for ``NodeClient.status`` for the ``Self.hash``
    public func status() async throws -> TransactionStatus {
        try await client.status(transaction: hash)
    }
}

/// Protocol for Concordium node clients targetting the GRPC v2 API
public protocol NodeClient {
    /// Get the global context for the chain
    func cryptographicParameters(block: BlockIdentifier) async throws -> CryptographicParameters
    /// Get the list of identity providers registered for the chain
    func identityProviders(block: BlockIdentifier) -> AsyncThrowingStream<IdentityProviderInfo, Error>
    /// Get the list of identity disclosure autorities registered for the chain
    func anonymityRevokers(block: BlockIdentifier) -> AsyncThrowingStream<AnonymityRevokerInfo, Error>
    /// Get the next account sequence number for the account
    func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber
    /// Get the account info for an account
    func info(account: AccountIdentifier, block: BlockIdentifier) async throws -> AccountInfo
    /// Get the account info for a block
    func info(block: BlockIdentifier) async throws -> BlockInfo
    /// Submit a transaction to the node
    func send(transaction: SignedAccountTransaction) async throws -> SubmittedTransaction
    /// Submit an account credential deployment to the node
    func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> SubmittedTransaction
    /// Query the status of a transaction
    func status(transaction: TransactionHash) async throws -> TransactionStatus
    /// Get a continuing stream of finalized blocks from the point in time where the method was invoked.
    func finalizedBlocks() -> AsyncThrowingStream<FinalizedBlockInfo, Error>
    /// Wait until the block identified by the supplied ``TransactionHash`` finalizes.
    /// - Returns: The hash of the block the transaction is included in, along with the associated transaction summary
    /// - Throws: `NOT_FOUND` GRPC error if the transaction is not known to the node.
    func waitUntilFinalized(transaction: TransactionHash, timeoutSeconds: UInt?) async throws -> (blockHash: BlockHash, summary: BlockItemSummary)
    /// Get the ``ConsensusInfo`` from the node
    func consensusInfo() async throws -> ConsensusInfo
    /// Get the ``ChainParameters`` from the node
    func chainParameters(block: BlockIdentifier) async throws -> ChainParameters
    /// Get the ``ElectionInfo`` containing information regarding active validators and election of these.
    func electionInfo(block: BlockIdentifier) async throws -> ElectionInfo
    // NOTE: The following methods should be implemented to allow wallets to transition to use GRPC client instead of wallet proxy.
    // TODO: func source(moduleRef: ModuleReference, block: BlockIdentifier) async throws -> WasmModule
    // TODO: func info(contractAddress: ContractAddress, block: BlockIdentifier) async throws -> InstanceInfo
    // TODO: func invokeInstance(request: ContractInvokeRequest, block: BlockIdentifier) async throws -> InvokeInstanceResult
    // TODO: func bakers(block: BlockIdentifier) async throws -> AsyncStream<AccountIndex>
    // TODO: func poolInfo(bakerId: AccountIndex, block: BlockIdentifier) async throws -> BakerPoolStatus
    // TODO: func passiveDelegationInfo(block: BlockIdentifier) async throws -> PassiveDelegationStatus
    // TODO: func tokenomicsInfo(block: BlockIdentifier) async throws -> RewardsOverview
}

/// Convert a GRPC response stream consisting of a GRPC type `V`, to an ``AsyncThrowingStream`` of ``R``
func convertStream<V, R>(for stream: GRPCAsyncResponseStream<V>, with transform: @escaping ((V) throws -> R)) -> AsyncThrowingStream<R, Error> where R: FromGRPC<V> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await value in stream {
                    try Task.checkCancellation()
                    continuation.yield(with: Result { try transform(value) })
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in task.cancel() }
    }
}

/// Convert a GRPC response stream consisting of a GRPC type `V`, to an ``AsyncThrowingStream`` of ``R``
func convertStream<V, R>(to _: R.Type, for stream: GRPCAsyncResponseStream<V>) -> AsyncThrowingStream<R, Error> where R: FromGRPC<V> {
    convertStream(for: stream, with: R.fromGRPC)
}

/// Error happening while constructing a ``NodeClient``
public struct NodeClientError: Error {
    public let message: String
}

/// Defines a GRPC client for communicating with the GRPC v2 API of a given Concordium node.
public class GRPCNodeClient: NodeClient {
    let grpc: Concordium_V2_QueriesAsyncClientProtocol

    init(_ grpc: Concordium_V2_QueriesAsyncClientProtocol) {
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
        self.init(Concordium_V2_QueriesAsyncClient(channel: channel))
    }

    public func cryptographicParameters(block: BlockIdentifier = BlockIdentifier.lastFinal) async throws -> CryptographicParameters {
        let req = block.toGRPC()
        let res = try await grpc.getCryptographicParameters(req)
        return .fromGRPC(res)
    }

    public func identityProviders(block: BlockIdentifier = BlockIdentifier.lastFinal) -> AsyncThrowingStream<IdentityProviderInfo, Error> {
        convertStream(to: IdentityProviderInfo.self, for: grpc.getIdentityProviders(block.toGRPC()))
    }

    public func anonymityRevokers(block: BlockIdentifier = BlockIdentifier.lastFinal) -> AsyncThrowingStream<AnonymityRevokerInfo, Error> {
        convertStream(to: AnonymityRevokerInfo.self, for: grpc.getAnonymityRevokers(block.toGRPC()))
    }

    public func nextAccountSequenceNumber(address: AccountAddress) async throws -> NextAccountSequenceNumber {
        let req = address.toGRPC()
        let res = try await grpc.getNextAccountSequenceNumber(req)
        return .fromGRPC(res)
    }

    public func info(account: AccountIdentifier, block: BlockIdentifier = BlockIdentifier.lastFinal) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGRPC()
        req.blockHash = block.toGRPC()
        let res = try await grpc.getAccountInfo(req)
        return try .fromGRPC(res)
    }

    public func info(block: BlockIdentifier = BlockIdentifier.lastFinal) async throws -> BlockInfo {
        let res = try await grpc.getBlockInfo(block.toGRPC())
        return try .fromGRPC(res)
    }

    public func send(transaction: SignedAccountTransaction) async throws -> SubmittedTransaction {
        var req = Concordium_V2_SendBlockItemRequest()
        req.accountTransaction = transaction.toGRPC()
        let res = try await grpc.sendBlockItem(req)
        return try SubmittedTransaction(hash: .fromGRPC(res), client: self)
    }

    public func send(deployment: SerializedSignedAccountCredentialDeployment) async throws -> SubmittedTransaction {
        var req = Concordium_V2_SendBlockItemRequest()
        req.credentialDeployment = deployment.toGRPC()
        let res = try await grpc.sendBlockItem(req)
        return try SubmittedTransaction(hash: .fromGRPC(res), client: self)
    }

    public func status(transaction: TransactionHash) async throws -> TransactionStatus {
        let res = try await grpc.getBlockItemStatus(transaction.toGRPC())
        return try .fromGRPC(res)
    }

    public func finalizedBlocks() -> AsyncThrowingStream<FinalizedBlockInfo, Error> {
        convertStream(to: FinalizedBlockInfo.self, for: grpc.getFinalizedBlocks(Concordium_V2_Empty()))
    }

    /// wait until finalization of transaction identified by the supplied ``TransactionHash``. This is kept private to encourage the use of timeouts through
    /// the public overload version
    private func waitUntilFinalized(transaction: TransactionHash) async throws -> (blockHash: BlockHash, summary: BlockItemSummary) {
        func process(_ tx: TransactionStatus) -> (blockHash: BlockHash, summary: BlockItemSummary)? {
            switch tx {
            case let .finalized(outcome):
                return outcome
            default:
                return nil
            }
        }

        var tx = try await status(transaction: transaction)
        if let outcome = process(tx) {
            return outcome
        } else {
            for try await _ in finalizedBlocks() {
                tx = try await status(transaction: transaction)
                if let outcome = process(tx) {
                    return outcome
                }
            }

            throw CancellationError()
        }
    }

    public func waitUntilFinalized(transaction: TransactionHash, timeoutSeconds: UInt? = nil) async throws -> (blockHash: BlockHash, summary: BlockItemSummary) {
        let result = try await withThrowingTaskGroup(of: (blockHash: BlockHash, summary: BlockItemSummary).self) { group in
            if let timeoutSeconds = timeoutSeconds {
                group.addTask {
                    let _ = try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw TimeoutError()
                }
            }

            group.addTask {
                try await self.waitUntilFinalized(transaction: transaction)
            }

            return try await group.next()!
        }

        return result
    }

    public func consensusInfo() async throws -> ConsensusInfo {
        try await .fromGRPC(grpc.getConsensusInfo(Concordium_V2_Empty()))
    }

    public func chainParameters(block: BlockIdentifier) async throws -> ChainParameters {
        try await .fromGRPC(grpc.getBlockChainParameters(block.toGRPC()))
    }

    public func electionInfo(block: BlockIdentifier) async throws -> ElectionInfo {
        try await .fromGRPC(grpc.getElectionInfo(block.toGRPC()))
    }
}

/// Signals that a timeout was hit prior to finishing a task.
public struct TimeoutError: Error {}
