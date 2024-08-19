import Foundation

public enum BlockIdentifier: ToGRPC {
    case lastFinal
    case best
    case hash(BlockHash)
    case absoluteHeight(UInt64)
    case relativeHeight(genesisIndex: UInt32, height: UInt64, restrictedToGenesisIndex: Bool)

    func toGRPC() -> Concordium_V2_BlockHashInput {
        switch self {
        case .lastFinal:
            var b = Concordium_V2_BlockHashInput()
            b.lastFinal = Concordium_V2_Empty()
            return b
        case .best:
            var b = Concordium_V2_BlockHashInput()
            b.best = Concordium_V2_Empty()
            return b
        case let .hash(hash):
            let h = hash.toGRPC()
            var b = Concordium_V2_BlockHashInput()
            b.given = h
            return b
        case let .absoluteHeight(height):
            var h = Concordium_V2_AbsoluteBlockHeight()
            h.value = height
            var b = Concordium_V2_BlockHashInput()
            b.absoluteHeight = h
            return b
        case let .relativeHeight(genesisIndex, height, restrictedToGenesisIndex):
            var h = Concordium_V2_BlockHashInput.RelativeHeight()
            var gh = Concordium_V2_GenesisIndex()
            gh.value = genesisIndex
            var bh = Concordium_V2_BlockHeight()
            bh.value = height
            h.genesisIndex = gh
            h.height = bh
            h.restrict = restrictedToGenesisIndex
            var b = Concordium_V2_BlockHashInput()
            b.relativeHeight = h
            return b
        }
    }
}

public struct BlockInfo: FromGRPC {
    typealias GRPC = Concordium_V2_BlockInfo

    /// Size of all the transactions in the block in bytes.
    public let transactionsSize: UInt64
    /// Parent block pointer.
    public let blockParent: BlockHash
    /// Hash of the block.
    public let blockHash: BlockHash
    /// Whether the block is finalized or not.
    public let finalized: Bool
    /// Hash of the block state at the end of the given block.
    public let blockStateHash: StateHash
    /// Time when the block was added to the node's tree. This is a subjective
    /// (i.e., node specific) value.
    public let blockArriveTime: Date
    /// Time when the block was first received by the node. This can be in
    /// principle quite different from the arrive time if, e.g., block execution
    /// takes a long time, or the block must wait for the arrival of its parent.
    public let blockReceiveTime: Date
    /// The number of transactions in the block.
    public let transactionCount: UInt64
    /// The total energy consumption of transactions in the block.
    public let transactionEnergyCost: Energy
    /// Slot number of the slot the block is in.
    /// This is only present up to protocol 5.
    public let blockSlot: Slot?
    /// Pointer to the last finalized block. Each block has a pointer to a
    /// specific finalized block that existed at the time the block was
    /// produced.
    public let blockLastFinalized: BlockHash
    /// Slot time of the slot the block is in. In contrast to
    /// [BlockInfo::block_arrive_time] this is an objective value, all nodes
    /// agree on it.
    public let blockSlotTime: Date
    /// Height of the block from genesis.
    public let blockHeight: UInt64
    /// The height of this block relative to the (re)genesis block of its era.
    public let eraBlockHeight: UInt64
    /// The genesis index for this block. This counts the number of protocol
    /// updates that have preceded this block, and defines the era of the
    /// block.
    public let genesisIndex: GenesisIndex
    /// Identity of the baker of the block. For non-genesis blocks the value is
    /// going to always be `Some`.
    public let blockBaker: BakerID?
    /// Protocol version to which the block belongs.
    public let protocolVersion: ProtocolVersion
    /// The round of the block. Present from protocol version 6.
    public let round: Round?
    /// The epoch of the block. Present from protocol version 6.
    public let epoch: Epoch?

    static func fromGRPC(_ g: GRPC) throws -> BlockInfo {
        try Self(
            transactionsSize: UInt64(g.transactionsSize),
            blockParent: .fromGRPC(g.parentBlock),
            blockHash: .fromGRPC(g.hash),
            finalized: g.finalized,
            blockStateHash: .fromGRPC(g.stateHash),
            blockArriveTime: Date(timeIntervalSince1970: Double(g.arriveTime.value)),
            blockReceiveTime: Date(timeIntervalSince1970: Double(g.receiveTime.value)),
            transactionCount: UInt64(g.transactionCount),
            transactionEnergyCost: g.transactionsEnergyCost.value,
            blockSlot: g.hasSlotTime ? g.slotNumber.value : nil,
            blockLastFinalized: .fromGRPC(g.lastFinalizedBlock),
            blockSlotTime: Date(timeIntervalSince1970: Double(g.slotTime.value)),
            blockHeight: g.height.value,
            eraBlockHeight: g.eraBlockHeight.value,
            genesisIndex: g.genesisIndex.value,
            blockBaker: g.hasBaker ? g.baker.value : nil,
            protocolVersion: .fromGRPC(g.protocolVersion),
            round: g.hasRound ? g.round.value : nil,
            epoch: g.hasEpoch ? g.epoch.value : nil
        )
    }
}

/// Represents a summary of a single transaction included in a block.
public struct BlockItemSummary {
    /// THe index of the transaction in the block where it is included.
    public let index: UInt64
    /// The amount of NRG the transaction cost.
    public let energy: Energy
    /// The hash of the transaction
    public let hash: TransactionHash
    /// The transaction details including the specific outcome.
    public let details: Details

    public enum Details {
        /// Represents an account transaction
        case accountTransaction(_ details: AccountTransactionDetails)
        /// Represents an account creation
        case accountCreation(_ details: AccountCreationDetails)
        /// Represents a chain update instruction
        case update(_ details: UpdateDetails)
    }
}

extension BlockItemSummary: FromGRPC {
    typealias GRPC = Concordium_V2_BlockItemSummary

    static func fromGRPC(_ g: GRPC) throws -> BlockItemSummary {
        let index = g.index.value
        let energy = g.energyCost.value
        let hash = try TransactionHash.fromGRPC(g.hash)

        let details: Details
        switch g.details {
        case nil:
            throw GRPCError.missingRequiredValue("Expected 'details' of 'BlockItemSummary' to be defined")
        case let .accountCreation(acd):
            details = try Details.accountCreation(.fromGRPC(acd))
        case let .accountTransaction(atd):
            details = try Details.accountTransaction(.fromGRPC(atd))
        case let .update(ud):
            details = try Details.update(.fromGRPC(ud))
        }

        return Self(index: index, energy: energy, hash: hash, details: details)
    }
}
