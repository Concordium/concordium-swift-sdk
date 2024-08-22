import Foundation
import NIO

/// Describes the possible status variants of a transaction submitted to a node.
public enum TransactionStatus {
    case received
    case committed(outcomes: [BlockHash: BlockItemSummary])
    case finalized(outcome: (blockHash: BlockHash, summary: BlockItemSummary))
}

extension TransactionStatus: FromGRPC {
    typealias GRPC = Concordium_V2_BlockItemStatus

    static func fromGRPC(_ g: GRPC) throws -> TransactionStatus {
        guard let status = g.status else { throw GRPCError.missingRequiredValue("Expected 'status' to be available for 'BlockItemStatus'") }
        switch status {
        case .received:
            return .received
        case let .committed(data):
            let outcomes = try data.outcomes.reduce(into: [:]) { acc, block in
                try acc[BlockHash.fromGRPC(block.blockHash)] = try BlockItemSummary.fromGRPC(block.outcome)
            }
            return .committed(outcomes: outcomes)
        case let .finalized(data):
            let blockHash = try BlockHash.fromGRPC(data.outcome.blockHash)
            let summary = try BlockItemSummary.fromGRPC(data.outcome.outcome)
            return .finalized(outcome: (blockHash: blockHash, summary: summary))
        }
    }
}

/// Information about the block finalized on chain as part of a stream of finalized blocks.
public struct FinalizedBlockInfo: FromGRPC {
    /// The block hash of the finalized block
    public let blockHash: BlockHash
    /// The absolute height of the block from the original genesis block of the chain
    public let absoluteHeight: UInt64

    typealias GRPC = Concordium_V2_FinalizedBlockInfo

    static func fromGRPC(_ g: GRPC) throws -> FinalizedBlockInfo {
        try .init(blockHash: .fromGRPC(g.hash), absoluteHeight: g.height.value)
    }
}

/// Summary of the current state of consensus.
public struct ConsensusInfo {
    /// Height of the last finalized block. Genesis block has height 0.
    public let lastFinalizedBlockHeight: UInt64
    /// The exponential moving average standard deviation of the time between a
    /// block's nominal slot time, and the time at which it is verified.
    public let blockArriveLatencyEMSD: Double
    /// Exponential moving average standard deviation of block receive latency
    /// (in seconds), i.e. the time between a block's nominal slot time, and
    /// the time at which is received.
    public let blockReceiveLatencyEMSD: Double
    /// Hash of the last, i.e., most recent, finalized block.
    public let lastFinalizedBlock: BlockHash
    /// Exponential moving average standard deviation of the time between
    /// receiving blocks (in seconds).
    public let blockReceivePeriodEMSD: Double?
    /// Exponential moving average standard deviation of the time between blocks
    /// being verified.
    public let blockArrivePeriodEMSD: Double?
    /// The number of blocks that have been received.
    public let blocksReceivedCount: UInt64
    /// Exponential moving average standard deviation of the number of
    /// transactions per block.
    public let transactionsPerBlockEMSD: Double
    /// Exponential moving average of the time between finalizations. Will be
    /// `None` if there are no finalizations yet since the node start.
    public let finalizationPeriodEMA: Double?
    /// Height of the best block.
    public let bestBlockHeight: UInt64
    /// Time at which a block last became finalized. Note that this is the local
    /// time of the node at the time the block was finalized.
    public let lastFinalizedTime: Date?
    /// The number of completed finalizations.
    public let finalizationCount: UInt64
    /// Duration of an epoch (in milliseconds).
    public let epochDuration: UInt64
    /// Number of blocks that arrived, i.e., were added to the tree. Note that
    /// in some cases this can be more than
    /// ``blocksReceivedCount`` since blocks that the node itself
    /// produces count towards this, but are not received.
    public let blocksVerifiedCount: UInt64
    /// Duration of a slot (in milliseconds)
    public let slotDuration: UInt64?
    /// Slot time of the genesis block.
    public let genesisTime: Date
    /// Exponential moving average standard deviation of the time between
    /// finalizations. Will be `none` if there are no finalizations yet
    /// since the node start.
    public let finalizationPeriodEMSD: Double?
    /// Exponential moving average of the number of
    /// transactions per block.
    public let transactionsPerBlockEMA: Double
    /// The exponential moving average of the time between a block's nominal
    /// slot time, and the time at which it is verified.
    public let blockArriveLatencyEMA: Double
    /// Exponential moving average of block receive latency (in seconds), i.e.
    /// the time between a block's nominal slot time, and the time at which is
    /// received.
    public let blockReceiveLatencyEMA: Double
    /// Exponential moving average of the time between receiving blocks (in
    /// seconds).
    public let blockArrivePeriodEMA: Double?
    /// Exponential moving average of the time between receiving blocks (in
    /// seconds).
    public let blockReceivePeriodEMA: Double?
    /// The time (local time of the node) that a block last arrived, i.e., was
    /// verified and added to the node's tree.
    public let blockLastArrivedTime: Date?
    /// Hash of the current best block. The best block is a protocol defined
    /// block that the node must use a parent block to build the chain on.
    /// Note that this is subjective, in the sense that it is only the best
    /// block among the blocks the node knows about.
    public let bestBlock: BlockHash
    /// Hash of the genesis block.
    public let genesisBlock: BlockHash
    /// The time (local time of the node) that a block was last received.
    public let blockLastReceivedTime: Date?
    /// Currently active protocol version.
    public let protocolVersion: ProtocolVersion
    /// The number of chain restarts via a protocol update. An effected
    /// protocol update instruction might not change the protocol version
    /// specified in the previous field, but it always increments the genesis
    /// index.
    public let genesisIndex: GenesisIndex
    /// Block hash of the genesis block of current era, i.e., since the last
    /// protocol update. Initially this is equal to
    /// ``genesisBlock``.
    public let currentEraGenesisBlock: BlockHash
    /// Time when the current era started.
    public let currentEraGenesisTime: Date
    /// Parameters that apply from protocol 6 onward. This is present if and
    /// only if the `protocolVersion` is ``ProtocolVersion.p6`` or later.
    public let concordiumBFTStatus: BFTDetails?

    /// Parameters pertaining to the Concordium BFT consensus.
    public struct BFTDetails {
        /// The current duration to wait before a round times out (in milliseconds).
        public let currentTimeoutDuration: UInt64
        /// The current round.
        public let currentRound: Round
        /// The current epoch.
        public let currentEpoch: Epoch
        /// The first block in the epoch with timestamp at least this is considered
        /// to be the trigger block for the epoch transition.
        public let triggerBlockTime: Date
    }
}

extension ConsensusInfo: FromGRPC {
    typealias GRPC = Concordium_V2_ConsensusInfo

    static func fromGRPC(_ g: GRPC) throws -> ConsensusInfo {
        let bftChecks = [g.hasCurrentTimeoutDuration, g.hasCurrentRound, g.hasCurrentEpoch, g.hasTriggerBlockTime]
        var bft: BFTDetails? = nil

        if bftChecks.allSatisfy({ $0 == true }) {
            bft = BFTDetails(
                currentTimeoutDuration: g.currentTimeoutDuration.value,
                currentRound: g.currentRound.value,
                currentEpoch: g.currentEpoch.value,
                triggerBlockTime: .fromGRPC(g.triggerBlockTime)
            )
        }

        return try Self(
            lastFinalizedBlockHeight: g.lastFinalizedBlockHeight.value,
            blockArriveLatencyEMSD: g.blockArriveLatencyEmsd,
            blockReceiveLatencyEMSD: g.blockReceiveLatencyEmsd,
            lastFinalizedBlock: .fromGRPC(g.lastFinalizedBlock),
            blockReceivePeriodEMSD: g.hasBlockReceivePeriodEmsd ? g.blockReceivePeriodEmsd : nil,
            blockArrivePeriodEMSD: g.hasBlockArrivePeriodEmsd ? g.blockArrivePeriodEmsd : nil,
            blocksReceivedCount: UInt64(g.blocksReceivedCount),
            transactionsPerBlockEMSD: g.transactionsPerBlockEmsd,
            finalizationPeriodEMA: g.hasFinalizationPeriodEma ? g.finalizationPeriodEma : nil,
            bestBlockHeight: g.bestBlockHeight.value,
            lastFinalizedTime: g.hasLastFinalizedTime ? .fromGRPC(g.lastFinalizedTime) : nil,
            finalizationCount: UInt64(g.finalizationCount),
            epochDuration: g.epochDuration.value,
            blocksVerifiedCount: UInt64(g.blocksVerifiedCount),
            slotDuration: g.hasSlotDuration ? g.slotDuration.value : nil,
            genesisTime: .fromGRPC(g.genesisTime),
            finalizationPeriodEMSD: g.hasFinalizationPeriodEmsd ? g.finalizationPeriodEmsd : nil,
            transactionsPerBlockEMA: g.transactionsPerBlockEma,
            blockArriveLatencyEMA: g.blockArriveLatencyEma,
            blockReceiveLatencyEMA: g.blockReceiveLatencyEma,
            blockArrivePeriodEMA: g.hasBlockArrivePeriodEma ? g.blockArrivePeriodEma : nil,
            blockReceivePeriodEMA: g.hasBlockReceivePeriodEma ? g.blockReceivePeriodEma : nil,
            blockLastArrivedTime: g.hasBlockLastArrivedTime ? .fromGRPC(g.blockLastArrivedTime) : nil,
            bestBlock: .fromGRPC(g.bestBlock),
            genesisBlock: .fromGRPC(g.genesisBlock),
            blockLastReceivedTime: g.hasBlockLastReceivedTime ? .fromGRPC(g.blockLastReceivedTime) : nil,
            protocolVersion: .fromGRPC(g.protocolVersion),
            genesisIndex: g.genesisIndex.value,
            currentEraGenesisBlock: .fromGRPC(g.currentEraGenesisBlock),
            currentEraGenesisTime: .fromGRPC(g.currentEraGenesisTime),
            concordiumBFTStatus: bft
        )
    }
}

/// Chain parameters. See ``ChainParametersV0``, ``ChainParametersV1`` and `ChainParametersV2` for
/// details. `v0` parameters apply to protocol version `1..=3`, `v1`
/// parameters apply to protocol versions `4..=5`, and `v2` parameters apply
/// to protocol versions `6..`.
public enum ChainParameters {
    /// protocol version `1..=3`
    case v0(_ params: ChainParametersV0)
    /// protocol version `4..=5`
    case v1(_ params: ChainParametersV1)
    /// protocol version `6..`
    case v2(_ params: ChainParametersV2)
}

/// The election difficulty with a precision of 1/100000.
public struct ElectionDifficulty: FromGRPC, Equatable, Serialize, Deserialize {
    public var partsPerHundredThousand: UInt32

    static func fromGRPC(_ g: Concordium_V2_ElectionDifficulty) -> Self {
        .init(partsPerHundredThousand: g.value.partsPerHundredThousand)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(partsPerHundredThousand)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(UInt32.self).flatMap { Self(partsPerHundredThousand: $0) }
    }
}

/// Represents possible errors from creating ``ExchangeRate``s
public enum RatioError: Error {
    /// Attempted to create a division where one of the parts were `0`
    case zeroValue
    /// The constructed exchange rate is not in its reduced form
    case nonReduced
}

func gcd<U: UnsignedInteger>(_ a: U, _ b: U) -> U {
    let remainder = a % b
    if remainder != 0 {
        return gcd(b, remainder)
    } else {
        return b
    }
}

public struct ExchangeRate {
    let numerator: UInt64
    let denominator: UInt64

    public init(numerator: UInt64, denominator: UInt64) throws {
        guard numerator != 0, denominator != 0 else { throw RatioError.zeroValue }
        guard gcd(numerator, denominator) == 1 else { throw RatioError.nonReduced }

        self.numerator = numerator
        self.denominator = denominator
    }
}

extension ExchangeRate: FromGRPC {
    typealias GRPC = Concordium_V2_ExchangeRate

    static func fromGRPC(_ g: GRPC) throws -> ExchangeRate {
        try Self(numerator: g.value.numerator, denominator: g.value.denominator) ?! GRPCError.valueOutOfBounds
    }
}

public struct Ratio {
    let numerator: UInt64
    let denominator: UInt64

    public init(numerator: UInt64, denominator: UInt64) throws {
        guard numerator != 0, denominator != 0 else { throw RatioError.zeroValue }
        guard gcd(numerator, denominator) == 1 else { throw RatioError.nonReduced }

        self.numerator = numerator
        self.denominator = denominator
    }
}

extension Ratio: FromGRPC {
    typealias GRPC = Concordium_V2_Ratio

    static func fromGRPC(_ g: GRPC) throws -> Ratio {
        try Self(numerator: g.numerator, denominator: g.denominator) ?! GRPCError.valueOutOfBounds
    }
}

/// Rate of creation of new CCDs. For example, A value of `0.05` would mean an
/// increase of 5 percent per unit of time. This value does not specify the time
/// unit, and this differs based on the protocol version.
///
/// The representation is base-10 floating point number representation.
/// The value is `mantissa * 10^(-exponent)`.
public struct MintRate {
    public let mantissa: UInt32
    public let exponent: UInt8
}

extension MintRate: FromGRPC {
    typealias GRPC = Concordium_V2_MintRate

    static func fromGRPC(_ g: GRPC) -> MintRate {
        Self(mantissa: g.mantissa, exponent: UInt8(g.exponent))
    }
}

/// Mint distribution that applies to protocol versions 1-3.
public struct MintDistributionV0 {
    /// The increase in CCD amount per slot.
    public let mintPerSlot: MintRate
    /// Fraction of newly minted CCD allocated to baker rewards.
    public let bakingReward: AmountFraction
    /// Fraction of newly minted CCD allocated to finalization rewards.
    public let finalizationReward: AmountFraction
}

extension MintDistributionV0: FromGRPC {
    typealias GRPC = Concordium_V2_MintDistributionCpv0

    static func fromGRPC(_ g: GRPC) -> MintDistributionV0 {
        Self(mintPerSlot: .fromGRPC(g.mintPerSlot), bakingReward: .fromGRPC(g.bakingReward), finalizationReward: .fromGRPC(g.finalizationReward))
    }
}

/// Mint distribution parameters that apply to protocol version 4 and up.
public struct MintDistributionV1 {
    /// Fraction of newly minted CCD allocated to baker rewards.
    public let bakingReward: AmountFraction
    /// Fraction of newly minted CCD allocated to finalization rewards.
    public let finalizationReward: AmountFraction
}

extension MintDistributionV1: FromGRPC {
    typealias GRPC = Concordium_V2_MintDistributionCpv1

    static func fromGRPC(_ g: GRPC) -> MintDistributionV1 {
        Self(bakingReward: .fromGRPC(g.bakingReward), finalizationReward: .fromGRPC(g.finalizationReward))
    }
}

/// Update the transaction fee distribution to the specified value.
public struct TransactionFeeDistribution {
    /// The fraction that goes to the baker of the block.
    public let baker: AmountFraction
    /// The fraction that goes to the gas account. The remaining fraction will
    /// go to the foundation.
    public let gasAccount: AmountFraction
}

extension TransactionFeeDistribution: FromGRPC {
    typealias GRPC = Concordium_V2_TransactionFeeDistribution

    static func fromGRPC(_ g: GRPC) throws -> TransactionFeeDistribution {
        let baker = AmountFraction.fromGRPC(g.baker)
        let gasAccount = AmountFraction.fromGRPC(g.gasAccount)
        guard let _ = baker + gasAccount else { throw GRPCError.valueOutOfBounds }

        return Self(baker: baker, gasAccount: gasAccount)
    }
}

/// The reward fractions related to the gas account and inclusion of special
/// transactions.
public struct GasRewards {
    /// `BakerPrevTransFrac`: fraction of the previous gas account paid to the
    /// baker.
    public let baker: AmountFraction
    /// `FeeAddFinalisationProof`: fraction paid for including a finalization
    /// proof in a block.
    public let finalizationProof: AmountFraction
    /// `FeeAccountCreation`: fraction paid for including each account creation
    /// transaction in a block.
    public let accountCreation: AmountFraction
    /// `FeeUpdate`: fraction paid for including an update transaction in a
    /// block.
    public let chainUpdate: AmountFraction
}

extension GasRewards: FromGRPC {
    typealias GRPC = Concordium_V2_GasRewards

    static func fromGRPC(_ g: GRPC) -> GasRewards {
        Self(baker: .fromGRPC(g.baker), finalizationProof: .fromGRPC(g.finalizationProof), accountCreation: .fromGRPC(g.accountCreation), chainUpdate: .fromGRPC(g.chainUpdate))
    }
}

/// The reward fractions related to the gas account and inclusion of special
/// transactions.
public struct GasRewardsV1 {
    /// `BakerPrevTransFrac`: fraction of the previous gas account paid to the
    /// baker.
    public let baker: AmountFraction
    /// `FeeAccountCreation`: fraction paid for including each account creation
    /// transaction in a block.
    public let accountCreation: AmountFraction
    /// `FeeUpdate`: fraction paid for including an update transaction in a
    /// block.
    public let chainUpdate: AmountFraction
}

extension GasRewardsV1: FromGRPC {
    typealias GRPC = Concordium_V2_GasRewardsCpv2

    static func fromGRPC(_ g: GRPC) -> GasRewardsV1 {
        Self(baker: .fromGRPC(g.baker), accountCreation: .fromGRPC(g.accountCreation), chainUpdate: .fromGRPC(g.chainUpdate))
    }
}

/// Either root, level1 access structure. They all have the same
/// structure, keys and a threshold. The phantom type parameter is used for
/// added type safety to distinguish different access structures in different
/// contexts.
public struct KeysWithThreshold {
    public let keys: [VerifyKey]
    public let threshold: UInt16
}

extension KeysWithThreshold: FromGRPC {
    typealias GRPC = Concordium_V2_HigherLevelKeys

    static func fromGRPC(_ g: GRPC) throws -> KeysWithThreshold {
        let keys = g.keys.map { VerifyKey.fromGRPCUpdateKey($0) }
        let threshold = UInt16(g.threshold.value)
        return Self(keys: keys, threshold: threshold)
    }
}

/// The current collection of keys allowed to do updates.
/// Parametrized by the level 2 keys corresponding to the chain parameters version
public struct UpdateKeysCollection<Authorizations> {
    public let rootKeys: KeysWithThreshold
    public let level1Keys: KeysWithThreshold
    public let level2Keys: Authorizations
}

// TODO: Add `FromGRPC` conformance from this point

/// And access structure for performing chain updates. The access structure is
/// only meaningful in the context of a list of update keys to which the indices
/// refer to.
public struct AccessStructure {
    /// The indices of the authorized keys
    public let authorizedKeys: Set<UInt16>
    public let threshold: UInt16
}

/// Access structures for each of the different possible chain updates, together
/// with the context giving all the possible keys.
public struct AuthorizationsV0 {
    /// The list of all keys that are currently authorized to perform updates.
    public let keys: [VerifyKey]
    /// Access structure for emergency updates.
    public let emergency: AccessStructure
    /// Access structure for protocol updates.
    public let protocolUpdate: AccessStructure
    /// Access structure for updating the election difficulty.
    public let electionDifficulty: AccessStructure
    /// Access structure for updating the euro to energy exchange rate.
    public let euroPerEnergy: AccessStructure
    /// Access structure for updating the microccd per euro exchange rate.
    public let microCCDPerEuro: AccessStructure
    /// Access structure for updating the foundation account address.
    public let foundationAccount: AccessStructure
    /// Access structure for updating the mint distribution parameters.
    public let mintDistribution: AccessStructure
    /// Access structure for updating the transaction fee distribution.
    public let transactionFeeDistribution: AccessStructure
    /// Access structure for updating the gas reward distribution parameters.
    public let paramGasRewards: AccessStructure
    /// Access structure for updating the pool parameters. For V0 this is only
    /// the baker stake threshold, for V1 there are more.
    public let poolParameters: AccessStructure
    /// Access structure for adding new anonymity revokers.
    public let addAnonymityRevoker: AccessStructure
    /// Access structure for adding new identity providers.
    public let addIdentityProvider: AccessStructure
}

public struct CooldownParameters {
    /// Number of seconds that pool owners must cooldown
    /// when reducing their equity capital or closing the pool.
    public let poolOwnerCooldownSeconds: UInt64
    /// Number of seconds that a delegator must cooldown
    /// when reducing their delegated stake.
    public let delegatorCooldownSeconds: UInt64
}

/// Parameters controlling consensus timeouts for the consensus protocol version
/// 2.
public struct TimeoutParameters {
    /// The base value for triggering a timeout.
    public let baseDurationMilliseconds: UInt64
    /// Factor for increasing the timeout. Must be greater than 1.
    public let increase: Ratio
    /// Factor for decreasing the timeout. Must be between 0 and 1.
    public let decrease: Ratio
}

/// The time parameters are introduced as of protocol version 4, and consist of
/// the reward period length and the mint rate per payday. These are coupled as
/// a change to either affects the overall rate of minting.
public struct TimeParameters {
    public let rewardPeriodLengthEpochs: Epoch
    public let mintPerPayday: MintRate
}

public struct InclusiveRange<T> {
    public let min: T
    public let max: T
}

/// Ranges of allowed commission values that pools may choose from.
public struct CommissionRanges {
    /// The range of allowed finalization commissions.
    public let finalizationCommissionRange: InclusiveRange<AmountFraction>
    /// The range of allowed baker commissions.
    public let bakingCommissionRange: InclusiveRange<AmountFraction>
    /// The range of allowed transaction commissions.
    public let transactionCommissionRange: InclusiveRange<AmountFraction>
}

/// Parameters related to staking pools. This applies to protocol version 4 and
/// up.
public struct PoolParameters {
    /// Fraction of finalization rewards charged by the passive delegation.
    public let passiveFinalizationCommission: AmountFraction
    /// Fraction of baking rewards charged by the passive delegation.
    public let passiveBakingCommission: AmountFraction
    /// Fraction of transaction rewards charged by the L-pool.
    public let passiveTransactionCommission: AmountFraction
    /// Bounds on the commission rates that may be charged by bakers.
    public let commissionBounds: CommissionRanges
    /// Minimum equity capital required for a new baker.
    public let minimumEquityCapital: Amount
    /// Maximum fraction of the total staked capital of that a new baker can
    /// have.
    public let capitalBound: AmountFraction
    /// The maximum leverage that a baker can have as a ratio of total stake
    /// to equity capital.
    public let leverageBound: Ratio
}

/// Finalization committee parameters. These parameters control which bakers are
/// in the finalization committee.
public struct FinalizationCommitteeParameters {
    /// Minimum number of bakers to include in the finalization committee before
    /// the 'finalizerRelativeStakeThreshold' takes effect.
    public let minFinalizers: UInt32
    /// Maximum number of bakers to include in the finalization committee.
    public let maxFinalizers: UInt32
    /// Determining the staking threshold required for being eligible the
    /// finalization committee. The required amount is given by `total stake
    /// in pools * finalizerRelativeStakeThreshold` provided as parts per
    /// hundred thousands. Accepted values are between a value of 0 and 1.
    public let finalizersRelativeStakeThreshold: AmountFraction
}

/// Access structures for each of the different possible chain updates, together
/// with the context giving all the possible keys.
public struct AuthorizationsV1 {
    /// The list of all keys that are currently authorized to perform updates.
    public let keys: [VerifyKey]
    /// Access structure for emergency updates.
    public let emergency: AccessStructure
    /// Access structure for protocol updates.
    public let protocolUpdate: AccessStructure
    /// Access structure for updating the election difficulty.
    public let electionDifficulty: AccessStructure
    /// Access structure for updating the euro to energy exchange rate.
    public let euroPerEnergy: AccessStructure
    /// Access structure for updating the microccd per euro exchange rate.
    public let microCCDPerEuro: AccessStructure
    /// Access structure for updating the foundation account address.
    public let foundationAccount: AccessStructure
    /// Access structure for updating the mint distribution parameters.
    public let mintDistribution: AccessStructure
    /// Access structure for updating the transaction fee distribution.
    public let transactionFeeDistribution: AccessStructure
    /// Access structure for updating the gas reward distribution parameters.
    public let paramGasRewards: AccessStructure
    /// Access structure for updating the pool parameters. For V0 this is only
    /// the baker stake threshold, for V1 there are more.
    public let poolParameters: AccessStructure
    /// Access structure for adding new anonymity revokers.
    public let addAnonymityRevoker: AccessStructure
    /// Access structure for adding new identity providers.
    public let addIdentityProvider: AccessStructure
    /// Keys for changing cooldown periods related to baking and delegating.
    public let cooldownParameters: AccessStructure
    /// Keys for changing the lenghts of the reward period.
    public let timeParameters: AccessStructure
}

/// Values of chain parameters that can be updated via chain updates.
/// This applies to protocol version 1-3.
public struct ChainParametersV0 {
    /// Election difficulty for consensus lottery.
    public let electionDifficulty: ElectionDifficulty
    /// Euro per energy exchange rate.
    public let euroPerEnergy: ExchangeRate
    /// Micro ccd per euro exchange rate.
    public let microCcdPerEuro: ExchangeRate
    /// Extra number of epochs before reduction in stake, or baker
    /// deregistration is completed.
    public let bakerCooldownEpochs: Epoch
    /// The limit for the number of account creations in a block.
    public let accountCreationLimit: UInt16
    /// Parameters related to the distribution of newly minted CCD.
    public let mintDistribution: MintDistributionV0
    /// Parameters related to the distribution of transaction fees.
    public let transactionFeeDistribution: TransactionFeeDistribution
    /// Parameters related to the distribution of the GAS account.
    public let gasRewards: GasRewards
    /// Address of the foundation account.
    public let foundationAccount: AccountAddress
    /// Minimum threshold for becoming a baker.
    public let minimumThresholdForBaking: Amount
    /// Keys allowed to do updates.
    public let keys: UpdateKeysCollection<AuthorizationsV0>
}

/// Values of chain parameters that can be updated via chain updates.
/// This applies to protocol version 4-5.
public struct ChainParametersV1 {
    /// Election difficulty for consensus lottery.
    public let electionDifficulty: ElectionDifficulty
    /// Euro per energy exchange rate.
    public let euroPerEnergy: ExchangeRate
    /// Micro ccd per euro exchange rate.
    public let microCcdPerEuro: ExchangeRate
    /// Parameters related to cooldowns when staking.
    public let cooldownParameters: CooldownParameters
    /// Parameters related mint rate and reward period.
    public let timeParameters: TimeParameters
    /// The limit for the number of account creations in a block.
    public let accountCreationLimit: UInt16
    /// Parameters related to the distribution of newly minted CCD.
    public let mintDistribution: MintDistributionV1
    /// Parameters related to the distribution of transaction fees.
    public let transactionFeeDistribution: TransactionFeeDistribution
    /// Parameters related to the distribution of the GAS account.
    public let gasRewards: GasRewards
    /// Address of the foundation account.
    public let foundationAccount: AccountAddress
    /// Parameters for baker pools.
    public let poolParameters: PoolParameters
    /// Keys allowed to do updates.
    public let keys: UpdateKeysCollection<AuthorizationsV1>
}

/// Values of chain parameters that can be updated via chain updates.
/// This applies to protocol version 6 and up.
public struct ChainParametersV2 {
    /// Election difficulty for consensus lottery.
    public let electionDifficulty: ElectionDifficulty
    /// Euro per energy exchange rate.
    public let euroPerEnergy: ExchangeRate
    /// Micro ccd per euro exchange rate.
    public let microCcdPerEuro: ExchangeRate
    /// Parameters related to cooldowns when staking.
    public let cooldownParameters: CooldownParameters
    /// Parameters related mint rate and reward period.
    public let timeParameters: TimeParameters
    /// The limit for the number of account creations in a block.
    public let accountCreationLimit: UInt16
    /// Parameters related to the distribution of newly minted CCD.
    public let mintDistribution: MintDistributionV1
    /// Parameters related to the distribution of transaction fees.
    public let transactionFeeDistribution: TransactionFeeDistribution
    /// Parameters related to the distribution of the GAS account.
    public let gasRewards: GasRewardsV1
    /// Address of the foundation account.
    public let foundationAccount: AccountAddress
    /// Parameters for baker pools.
    public let poolParameters: PoolParameters
    /// Consensus protocol version 2 timeout parameters.
    public let timeoutParameters: TimeoutParameters
    /// Minimum time interval between blocks.
    public let minBlockTimeMilliseconds: UInt64
    /// Maximum energy allowed per block.
    public let blockEnergyLimit: Energy
    /// The finalization committee parameters.
    public let finalizationCommitteeParameters: FinalizationCommitteeParameters
    /// Keys allowed to do updates.
    public let keys: UpdateKeysCollection<AuthorizationsV1>
}
