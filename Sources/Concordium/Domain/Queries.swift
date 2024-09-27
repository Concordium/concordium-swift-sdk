import ConcordiumWalletCrypto
import Foundation
import NIO

public typealias CryptographicParameters = ConcordiumWalletCrypto.GlobalContext

extension CryptographicParameters: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_CryptographicParameters) -> Self {
        .init(
            onChainCommitmentKey: grpc.onChainCommitmentKey,
            bulletproofGenerators: grpc.bulletproofGenerators,
            genesisString: grpc.genesisString
        )
    }
}

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

extension ChainParameters: FromGRPC {
    typealias GRPC = Concordium_V2_ChainParameters

    static func fromGRPC(_ g: GRPC) throws -> ChainParameters {
        let gChainParameters = try g.parameters ?! GRPCError.missingRequiredValue("Missing parameters enum")
        switch gChainParameters {
        case let .v0(v0): return try .v0(.fromGRPC(v0))
        case let .v1(v1): return try .v1(.fromGRPC(v1))
        case let .v2(v2): return try .v2(.fromGRPC(v2))
        }
    }
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

    /// Floating point representation of the ``AmountFraction``
    public var value: Double { Double(partsPerHundredThousand) / 100_000 }
}

extension ElectionDifficulty: CustomStringConvertible {
    public var description: String { "\(value)" }
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

    /// Represents the ``ExchangeRate`` as ``Double``. For values consisting of very big numbers, this might result in loss of precision.
    public var value: Double { Double(numerator) / Double(denominator) }
}

extension ExchangeRate: FromGRPC {
    typealias GRPC = Concordium_V2_ExchangeRate

    static func fromGRPC(_ g: GRPC) throws -> ExchangeRate {
        try Self(numerator: g.value.numerator, denominator: g.value.denominator) ?! GRPCError.valueOutOfBounds
    }
}

extension ExchangeRate: CustomStringConvertible {
    public var description: String { "\(value)" }
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

    /// Represents the ``Ratio`` as ``Double``. For values consisting of very big numbers, this might result in loss of precision.
    public var value: Double { Double(numerator) / Double(denominator) }
}

extension Ratio: FromGRPC {
    typealias GRPC = Concordium_V2_Ratio

    static func fromGRPC(_ g: GRPC) throws -> Ratio {
        try Self(numerator: g.numerator, denominator: g.denominator) ?! GRPCError.valueOutOfBounds
    }
}

extension Ratio: CustomStringConvertible {
    public var description: String { "\(value)" }
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

    /// Represents the ``MintRate`` as ``Double``. For values consisting of very big numbers, this might result in loss of precision.
    public var value: Double { Double(mantissa) * pow(10, Double(exponent)) }
}

extension MintRate: CustomStringConvertible {
    public var description: String { "\(value)" }
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

    static func fromGRPC(_ g: GRPC) -> KeysWithThreshold {
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

/// And access structure for performing chain updates. The access structure is
/// only meaningful in the context of a list of update keys to which the indices
/// refer to.
public struct AccessStructure {
    /// The indices of the authorized keys
    public let authorizedKeys: Set<UInt16>
    public let threshold: UInt16
}

extension AccessStructure: FromGRPC {
    typealias GRPC = Concordium_V2_AccessStructure

    static func fromGRPC(_ g: GRPC) -> AccessStructure {
        let authorizedKeys = Set(g.accessPublicKeys.map { UInt16($0.value) })
        return Self(authorizedKeys: authorizedKeys, threshold: UInt16(g.accessThreshold.value))
    }
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
    public let gasRewards: AccessStructure
    /// Access structure for updating the pool parameters. For V0 this is only
    /// the baker stake threshold, for V1 there are more.
    public let poolParameters: AccessStructure
    /// Access structure for adding new anonymity revokers.
    public let addAnonymityRevoker: AccessStructure
    /// Access structure for adding new identity providers.
    public let addIdentityProvider: AccessStructure
}

extension AuthorizationsV0: FromGRPC {
    typealias GRPC = Concordium_V2_AuthorizationsV0

    static func fromGRPC(_ g: GRPC) -> AuthorizationsV0 {
        let keys = g.keys.map { VerifyKey.fromGRPCUpdateKey($0) }
        return Self(
            keys: keys,
            emergency: .fromGRPC(g.emergency),
            protocolUpdate: .fromGRPC(g.protocol),
            electionDifficulty: .fromGRPC(g.parameterConsensus),
            euroPerEnergy: .fromGRPC(g.parameterEuroPerEnergy),
            microCCDPerEuro: .fromGRPC(g.parameterMicroCcdPerEuro),
            foundationAccount: .fromGRPC(g.parameterFoundationAccount),
            mintDistribution: .fromGRPC(g.parameterMintDistribution),
            transactionFeeDistribution: .fromGRPC(g.parameterTransactionFeeDistribution),
            gasRewards: .fromGRPC(g.parameterGasRewards),
            poolParameters: .fromGRPC(g.poolParameters),
            addAnonymityRevoker: .fromGRPC(g.addAnonymityRevoker),
            addIdentityProvider: .fromGRPC(g.addIdentityProvider)
        )
    }
}

public struct CooldownParameters {
    /// Number of seconds that pool owners must cooldown
    /// when reducing their equity capital or closing the pool.
    public let poolOwnerCooldownSeconds: UInt64
    /// Number of seconds that a delegator must cooldown
    /// when reducing their delegated stake.
    public let delegatorCooldownSeconds: UInt64
}

extension CooldownParameters: FromGRPC {
    typealias GRPC = Concordium_V2_CooldownParametersCpv1

    static func fromGRPC(_ g: GRPC) -> CooldownParameters {
        Self(poolOwnerCooldownSeconds: g.poolOwnerCooldown.value, delegatorCooldownSeconds: g.delegatorCooldown.value)
    }
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

extension TimeoutParameters: FromGRPC {
    typealias GRPC = Concordium_V2_TimeoutParameters

    static func fromGRPC(_ g: GRPC) throws -> TimeoutParameters {
        try Self(baseDurationMilliseconds: g.timeoutBase.value, increase: .fromGRPC(g.timeoutIncrease), decrease: .fromGRPC(g.timeoutDecrease))
    }
}

/// The time parameters are introduced as of protocol version 4, and consist of
/// the reward period length and the mint rate per payday. These are coupled as
/// a change to either affects the overall rate of minting.
public struct TimeParameters {
    public let rewardPeriodLengthEpochs: Epoch
    public let mintPerPayday: MintRate
}

extension TimeParameters: FromGRPC {
    typealias GRPC = Concordium_V2_TimeParametersCpv1

    static func fromGRPC(_ g: GRPC) -> TimeParameters {
        Self(rewardPeriodLengthEpochs: g.rewardPeriodLength.value.value, mintPerPayday: .fromGRPC(g.mintPerPayday))
    }
}

public struct InclusiveRange<T> {
    public let min: T
    public let max: T
}

extension InclusiveRange: FromGRPC where T == AmountFraction {
    typealias GRPC = Concordium_V2_InclusiveRangeAmountFraction

    static func fromGRPC(_ g: GRPC) -> InclusiveRange {
        Self(min: .fromGRPC(g.min), max: .fromGRPC(g.max_))
    }
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

extension CommissionRanges: FromGRPC {
    typealias GRPC = Concordium_V2_CommissionRanges

    static func fromGRPC(_ g: GRPC) -> CommissionRanges {
        Self(finalizationCommissionRange: .fromGRPC(g.finalization), bakingCommissionRange: .fromGRPC(g.baking), transactionCommissionRange: .fromGRPC(g.transaction))
    }
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
    public let minimumEquityCapital: CCD
    /// Maximum fraction of the total staked capital of that a new baker can
    /// have.
    public let capitalBound: AmountFraction
    /// The maximum leverage that a baker can have as a ratio of total stake
    /// to equity capital.
    public let leverageBound: Ratio
}

extension PoolParameters: FromGRPC {
    typealias GRPC = Concordium_V2_PoolParametersCpv1

    static func fromGRPC(_ g: GRPC) throws -> PoolParameters {
        try Self(
            passiveFinalizationCommission: .fromGRPC(g.passiveFinalizationCommission),
            passiveBakingCommission: .fromGRPC(g.passiveBakingCommission),
            passiveTransactionCommission: .fromGRPC(g.passiveTransactionCommission),
            commissionBounds: .fromGRPC(g.commissionBounds),
            minimumEquityCapital: .fromGRPC(g.minimumEquityCapital),
            capitalBound: .fromGRPC(g.capitalBound.value),
            leverageBound: .fromGRPC(g.leverageBound.value)
        )
    }
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

extension FinalizationCommitteeParameters: FromGRPC {
    typealias GRPC = Concordium_V2_FinalizationCommitteeParameters

    static func fromGRPC(_ g: GRPC) throws -> FinalizationCommitteeParameters {
        Self(minFinalizers: g.minimumFinalizers, maxFinalizers: g.maximumFinalizers, finalizersRelativeStakeThreshold: .fromGRPC(g.finalizerRelativeStakeThreshold))
    }
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
    public let gasRewards: AccessStructure
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

extension AuthorizationsV1: FromGRPC {
    typealias GRPC = Concordium_V2_AuthorizationsV1

    static func fromGRPC(_ g: GRPC) -> AuthorizationsV1 {
        let keys = g.v0.keys.map { VerifyKey.fromGRPCUpdateKey($0) }
        return Self(
            keys: keys,
            emergency: .fromGRPC(g.v0.emergency),
            protocolUpdate: .fromGRPC(g.v0.protocol),
            electionDifficulty: .fromGRPC(g.v0.parameterConsensus),
            euroPerEnergy: .fromGRPC(g.v0.parameterEuroPerEnergy),
            microCCDPerEuro: .fromGRPC(g.v0.parameterMicroCcdPerEuro),
            foundationAccount: .fromGRPC(g.v0.parameterFoundationAccount),
            mintDistribution: .fromGRPC(g.v0.parameterMintDistribution),
            transactionFeeDistribution: .fromGRPC(g.v0.parameterTransactionFeeDistribution),
            gasRewards: .fromGRPC(g.v0.parameterGasRewards),
            poolParameters: .fromGRPC(g.v0.poolParameters),
            addAnonymityRevoker: .fromGRPC(g.v0.addAnonymityRevoker),
            addIdentityProvider: .fromGRPC(g.v0.addIdentityProvider),
            cooldownParameters: .fromGRPC(g.parameterCooldown),
            timeParameters: .fromGRPC(g.parameterTime)
        )
    }
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
    public let minimumThresholdForBaking: CCD
    /// Keys allowed to do updates.
    public let keys: UpdateKeysCollection<AuthorizationsV0>
}

extension ChainParametersV0: FromGRPC {
    typealias GRPC = Concordium_V2_ChainParametersV0

    static func fromGRPC(_ g: GRPC) throws -> ChainParametersV0 {
        try Self(
            electionDifficulty: .fromGRPC(g.electionDifficulty),
            euroPerEnergy: .fromGRPC(g.euroPerEnergy),
            microCcdPerEuro: .fromGRPC(g.microCcdPerEuro),
            bakerCooldownEpochs: g.bakerCooldownEpochs.value,
            accountCreationLimit: UInt16(g.accountCreationLimit.value),
            mintDistribution: .fromGRPC(g.mintDistribution),
            transactionFeeDistribution: .fromGRPC(g.transactionFeeDistribution),
            gasRewards: .fromGRPC(g.gasRewards),
            foundationAccount: .fromGRPC(g.foundationAccount),
            minimumThresholdForBaking: .fromGRPC(g.minimumThresholdForBaking),
            keys: .init(rootKeys: .fromGRPC(g.rootKeys), level1Keys: .fromGRPC(g.level1Keys), level2Keys: .fromGRPC(g.level2Keys))
        )
    }
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

extension ChainParametersV1: FromGRPC {
    typealias GRPC = Concordium_V2_ChainParametersV1

    static func fromGRPC(_ g: GRPC) throws -> ChainParametersV1 {
        try Self(
            electionDifficulty: .fromGRPC(g.electionDifficulty),
            euroPerEnergy: .fromGRPC(g.euroPerEnergy),
            microCcdPerEuro: .fromGRPC(g.microCcdPerEuro),
            cooldownParameters: .fromGRPC(g.cooldownParameters),
            timeParameters: .fromGRPC(g.timeParameters),
            accountCreationLimit: UInt16(g.accountCreationLimit.value),
            mintDistribution: .fromGRPC(g.mintDistribution),
            transactionFeeDistribution: .fromGRPC(g.transactionFeeDistribution),
            gasRewards: .fromGRPC(g.gasRewards),
            foundationAccount: .fromGRPC(g.foundationAccount),
            poolParameters: .fromGRPC(g.poolParameters),
            keys: .init(rootKeys: .fromGRPC(g.rootKeys), level1Keys: .fromGRPC(g.level1Keys), level2Keys: .fromGRPC(g.level2Keys))
        )
    }
}

/// Values of chain parameters that can be updated via chain updates.
/// This applies to protocol version 6 and up.
public struct ChainParametersV2 {
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

extension ChainParametersV2: FromGRPC {
    typealias GRPC = Concordium_V2_ChainParametersV2

    static func fromGRPC(_ g: GRPC) throws -> ChainParametersV2 {
        try Self(
            euroPerEnergy: .fromGRPC(g.euroPerEnergy),
            microCcdPerEuro: .fromGRPC(g.microCcdPerEuro),
            cooldownParameters: .fromGRPC(g.cooldownParameters),
            timeParameters: .fromGRPC(g.timeParameters),
            accountCreationLimit: UInt16(g.accountCreationLimit.value),
            mintDistribution: .fromGRPC(g.mintDistribution),
            transactionFeeDistribution: .fromGRPC(g.transactionFeeDistribution),
            gasRewards: .fromGRPC(g.gasRewards),
            foundationAccount: .fromGRPC(g.foundationAccount),
            poolParameters: .fromGRPC(g.poolParameters),
            timeoutParameters: .fromGRPC(g.consensusParameters.timeoutParameters),
            minBlockTimeMilliseconds: g.consensusParameters.minBlockTime.value,
            blockEnergyLimit: g.consensusParameters.blockEnergyLimit.value,
            finalizationCommitteeParameters: .fromGRPC(g.finalizationCommitteeParameters),
            keys: .init(rootKeys: .fromGRPC(g.rootKeys), level1Keys: .fromGRPC(g.level1Keys), level2Keys: .fromGRPC(g.level2Keys))
        )
    }
}

/// Represents a Concordium transaction hash
public struct LeadershipElectionNonce: HashBytes, ToGRPC, FromGRPC, Equatable, Hashable {
    public let value: Data
    public init(unchecked value: Data) {
        self.value = value
    }

    func toGRPC() -> Concordium_V2_LeadershipElectionNonce {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_LeadershipElectionNonce) throws -> Self {
        try Self(g.value)
    }
}

extension LeadershipElectionNonce: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension LeadershipElectionNonce: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// The state of consensus parameters, and allowed participants (i.e., bakers).
public struct ElectionInfo {
    /// Current election difficulty. This is only present for protocol versions
    /// 1-5.
    public let electionDifficulty: ElectionDifficulty?
    /// Leadership election nonce for the current epoch.
    public let electionNonce: LeadershipElectionNonce
    /// The list of active bakers.
    public let bakers: [Baker]
}

extension ElectionInfo: FromGRPC {
    typealias GRPC = Concordium_V2_ElectionInfo

    static func fromGRPC(_ g: GRPC) throws -> ElectionInfo {
        let electionDifficulty = g.hasElectionDifficulty ? ElectionDifficulty.fromGRPC(g.electionDifficulty) : nil
        let bakers = try g.bakerElectionInfo.map(Baker.fromGRPC)
        return try Self(electionDifficulty: electionDifficulty, electionNonce: .fromGRPC(g.electionNonce), bakers: bakers)
    }
}

/// State of an individual baker.
public struct Baker {
    /// ID of the baker. Matches their account index.
    public let bakerId: BakerID
    /// The lottery power of the baker. This is the baker's stake relative to
    /// the total staked amount.
    public let bakerLotteryPower: Double
    /// Address of the account this baker is associated with.
    public let bakerAccount: AccountAddress
}

extension Baker: FromGRPC {
    typealias GRPC = Concordium_V2_ElectionInfo.Baker

    static func fromGRPC(_ g: GRPC) throws -> Baker {
        Self(bakerId: g.baker.value, bakerLotteryPower: g.lotteryPower, bakerAccount: try .fromGRPC(g.account))
    }
}

/// Tokenomics info for protocol version `1..=3`
public struct TokenomicsInfoV0 {
    /// Protocol version that applies to these rewards. V0 variant
    /// only exists for protocol versions 1, 2, and 3.
    public let protocolVersion: ProtocolVersion
    /// The total CCD in existence.
    public let totalAmount: CCD
    /// The total CCD in encrypted balances.
    public let totalEncryptedAmount: CCD
    /// The amount in the baking reward account.
    public let bakingRewardAccount: CCD
    /// The amount in the finalization reward account.
    public let finalizationRewardAccount: CCD
    /// The amount in the GAS account.
    public let gasAccount: CCD
}

extension TokenomicsInfoV0: FromGRPC {
    typealias GRPC = Concordium_V2_TokenomicsInfo.V0

    static func fromGRPC(_ g: GRPC) throws -> TokenomicsInfoV0 {
        try Self(
            protocolVersion: .fromGRPC(g.protocolVersion),
            totalAmount: .fromGRPC(g.totalAmount),
            totalEncryptedAmount: .fromGRPC(g.totalEncryptedAmount),
            bakingRewardAccount: .fromGRPC(g.bakingRewardAccount),
            finalizationRewardAccount: .fromGRPC(g.finalizationRewardAccount),
            gasAccount: .fromGRPC(g.gasAccount)
        )
    }
}

/// Tokenomics info for protocol version `4..`
public struct TokenomicsInfoV1 {
    /// Protocol version that applies to these rewards. V0 variant
    /// only exists for protocol versions 1, 2, and 3.
    public let protocolVersion: ProtocolVersion
    /// The total CCD in existence.
    public let totalAmount: CCD
    /// The total CCD in encrypted balances.
    public let totalEncryptedAmount: CCD
    /// The amount in the baking reward account.
    public let bakingRewardAccount: CCD
    /// The amount in the finalization reward account.
    public let finalizationRewardAccount: CCD
    /// The amount in the GAS account.
    public let gasAccount: CCD
    /// The transaction reward fraction accruing to the foundation (to be
    /// paid at next payday).
    public let foundationTransactionRewards: CCD
    /// The time of the next payday.
    public let nextPaydayTime: Date
    /// The rate at which CCD will be minted (as a proportion of the total
    /// supply) at the next payday
    public let nextPaydayMintRate: MintRate
    /// The total capital put up as stake by bakers and delegators
    public let totalStakedCapital: CCD
}

extension TokenomicsInfoV1: FromGRPC {
    typealias GRPC = Concordium_V2_TokenomicsInfo.V1

    static func fromGRPC(_ g: GRPC) throws -> TokenomicsInfoV1 {
        try Self(
            protocolVersion: .fromGRPC(g.protocolVersion),
            totalAmount: .fromGRPC(g.totalAmount),
            totalEncryptedAmount: .fromGRPC(g.totalEncryptedAmount),
            bakingRewardAccount: .fromGRPC(g.bakingRewardAccount),
            finalizationRewardAccount: .fromGRPC(g.finalizationRewardAccount),
            gasAccount: .fromGRPC(g.gasAccount),
            foundationTransactionRewards: .fromGRPC(g.foundationTransactionRewards),
            nextPaydayTime: .fromGRPC(g.nextPaydayTime),
            nextPaydayMintRate: .fromGRPC(g.nextPaydayMintRate),
            totalStakedCapital: .fromGRPC(g.totalStakedCapital)
        )
    }
}

/// Describes the different versions of tokenomics info across all protocol versions
public enum TokenomicsInfo {
    /// Protocol version `1..=3`
    case v0(_ info: TokenomicsInfoV0)
    /// Protocol version `4..`
    case v1(_ info: TokenomicsInfoV1)
}

extension TokenomicsInfo: FromGRPC {
    typealias GRPC = Concordium_V2_TokenomicsInfo

    static func fromGRPC(_ g: GRPC) throws -> TokenomicsInfo {
        let info = try g.tokenomics ?! GRPCError.missingRequiredValue("Missing 'tokenomics' value")

        switch info {
        case let .v0(v0): return try .v0(.fromGRPC(v0))
        case let .v1(v1): return try .v1(.fromGRPC(v1))
        }
    }
}

public struct InstanceInfoV0 {
    public let model: Data
    public let owner: AccountAddress
    public let amount: CCD
    public let methods: Set<ReceiveName>
    public let name: InitName
    public let sourceModule: ModuleReference
}

extension InstanceInfoV0: FromGRPC {
    typealias GRPC = Concordium_V2_InstanceInfo.V0

    static func fromGRPC(_ g: GRPC) throws -> InstanceInfoV0 {
        let methods = try Set(g.methods.map(ReceiveName.fromGRPC))
        return try Self(
            model: g.model.value,
            owner: .fromGRPC(g.owner),
            amount: .fromGRPC(g.amount),
            methods: methods,
            name: .fromGRPC(g.name),
            sourceModule: .fromGRPC(g.sourceModule)
        )
    }
}

public struct InstanceInfoV1 {
    public let owner: AccountAddress
    public let amount: CCD
    public let methods: Set<ReceiveName>
    public let name: InitName
    public let sourceModule: ModuleReference
}

extension InstanceInfoV1: FromGRPC {
    typealias GRPC = Concordium_V2_InstanceInfo.V1

    static func fromGRPC(_ g: GRPC) throws -> InstanceInfoV1 {
        let methods = try Set(g.methods.map(ReceiveName.fromGRPC))
        return try Self(
            owner: .fromGRPC(g.owner),
            amount: .fromGRPC(g.amount),
            methods: methods,
            name: .fromGRPC(g.name),
            sourceModule: .fromGRPC(g.sourceModule)
        )
    }
}

/// Holds information of a contract instance
public enum InstanceInfo {
    case v0(_ info: InstanceInfoV0)
    case v1(_ info: InstanceInfoV1)
}

extension InstanceInfo: FromGRPC {
    typealias GRPC = Concordium_V2_InstanceInfo

    static func fromGRPC(_ g: GRPC) throws -> InstanceInfo {
        let info = try g.version ?! GRPCError.missingRequiredValue("Missing 'version' value")

        switch info {
        case let .v0(v0): return try .v0(.fromGRPC(v0))
        case let .v1(v1): return try .v1(.fromGRPC(v1))
        }
    }
}

public struct InvokeContractSuccess {
    public let returnValue: Data?
    public let events: [ContractTraceElement]
    public let usedEnergy: Energy
}

public struct InvokeContractFailure: Error {
    public let returnValue: Data?
    public let rejectReason: RejectReason
    public let usedEnergy: Energy
}

public enum InvokeContractResult {
    case success(_ value: InvokeContractSuccess)
    case failure(_ value: InvokeContractFailure)

    public var usedEnergy: Energy {
        switch self {
        case let .success(v): return v.usedEnergy
        case let .failure(v): return v.usedEnergy
        }
    }

    /// Converts the result to a ``InvokeContractSuccess``
    ///
    /// - Throws: ``InvokeContractFailure`` if the result is not a ``.success``
    public func success() throws -> InvokeContractSuccess {
        switch self {
        case let .success(value): return value
        case let .failure(value): throw value
        }
    }
}

extension InvokeContractResult: FromGRPC {
    typealias GRPC = Concordium_V2_InvokeInstanceResponse

    static func fromGRPC(_ g: GRPC) throws -> InvokeContractResult {
        let result = try g.result ?! GRPCError.missingRequiredValue("Missing 'result' of value")

        switch result {
        case let .success(value):
            let events = try value.effects.map(ContractTraceElement.fromGRPC)
            return .success(InvokeContractSuccess(returnValue: value.returnValue, events: events, usedEnergy: value.usedEnergy.value))
        case let .failure(value):
            return try .failure(InvokeContractFailure(returnValue: value.returnValue, rejectReason: .fromGRPC(value.reason), usedEnergy: value.usedEnergy.value))
        }
    }
}

/// Data needed to invoke the contract.
public struct ContractInvokeRequest {
    /// Invoker of the contract. If this is not supplied then the contract will
    /// be invoked, by an account with address 0, no credentials and
    /// sufficient amount of CCD to cover the transfer amount. If given, the
    /// relevant address must exist in the blockstate.
    public var invoker: Address?
    /// Contract to invoke.
    public var contract: ContractAddress
    /// Amount to invoke the contract with.
    public var amount: CCD
    /// Which entrypoint to invoke.
    public var method: ReceiveName
    /// And with what parameter.
    public var parameter: Parameter
    /// The energy to allow for execution. If not set the node decides on the
    /// maximum amount.
    public var energy: Energy?

    public init(contract: ContractAddress, method: ReceiveName) {
        invoker = nil
        self.contract = contract
        amount = CCD(microCCD: 0)
        self.method = method
        parameter = Parameter(unchecked: Data())
        energy = nil
    }
}

extension Concordium_V2_Energy {
    init(_ value: UInt64) {
        self.value = value
    }
}

extension ContractInvokeRequest {
    func toGRPC(with block: BlockIdentifier) -> Concordium_V2_InvokeInstanceRequest {
        var req = Concordium_V2_InvokeInstanceRequest()
        req.blockHash = block.toGRPC()
        if let invoker = invoker {
            req.invoker = invoker.toGRPC()
        }
        req.instance = contract.toGRPC()
        req.amount = amount.toGRPC()
        req.entrypoint = method.toGRPC()
        req.parameter = parameter.toGRPC()
        if let energy = energy {
            req.energy = Concordium_V2_Energy(energy)
        }
        return req
    }
}

public enum PoolPendingChange {
    case noChange
    case reduceBakerCapital(bakerEquityCapital: CCD, effectiveTime: Date)
    case removePool(effectiveTime: Date)
}

extension PoolPendingChange: FromGRPC {
    typealias GRPC = Concordium_V2_PoolPendingChange

    static func fromGRPC(_ g: GRPC) throws -> PoolPendingChange {
        guard let change = g.change else { return .noChange }

        switch change {
        case let .reduce(value): return try .reduceBakerCapital(bakerEquityCapital: .fromGRPC(value.reducedEquityCapital), effectiveTime: .fromGRPC(value.effectiveTime))
        case let .remove(value): return .removePool(effectiveTime: .fromGRPC(value.effectiveTime))
        }
    }
}

public struct CurrentPaydayBakerPoolStatus {
    /// The number of blocks baked in the current reward period.
    public let blocksBaked: UInt64
    /// Whether the baker has contributed a finalization proof in the current
    /// reward period.
    public let finalizationLive: Bool
    /// The transaction fees accruing to the pool in the current reward period.
    public let transactionFeesEarned: CCD
    /// The effective stake of the baker in the current reward period.
    public let effectiveStake: CCD
    /// The lottery power of the baker in the current reward period.
    public let lotteryPower: Double
    /// The effective equity capital of the baker for the current reward period.
    public let bakerEquityCapital: CCD
    /// The effective delegated capital to the pool for the current reward
    /// period.
    public let delegatedCapital: CCD
    /// The commission rates that apply for the current reward period for the
    /// baker pool.
    public let commissionRates: CommissionRates
}

extension CurrentPaydayBakerPoolStatus: FromGRPC {
    typealias GRPC = Concordium_V2_PoolCurrentPaydayInfo

    static func fromGRPC(_ g: GRPC) throws -> CurrentPaydayBakerPoolStatus {
        try Self(
            blocksBaked: g.blocksBaked,
            finalizationLive: g.finalizationLive,
            transactionFeesEarned: .fromGRPC(g.transactionFeesEarned),
            effectiveStake: .fromGRPC(g.effectiveStake),
            lotteryPower: g.lotteryPower,
            bakerEquityCapital: .fromGRPC(g.bakerEquityCapital),
            delegatedCapital: .fromGRPC(g.delegatedCapital),
            commissionRates: .fromGRPC(g.commissionRates)
        )
    }
}

/// The state of the baker currently registered on the account.
/// Current here means "present". This is the information that is being updated
/// by transactions (and rewards). This is in contrast to "epoch baker" which is
/// the state of the baker that is currently eligible for baking.
public struct BakerPoolStatus {
    /// The 'BakerID' of the pool owner.
    public let bakerId: BakerID
    /// The account address of the pool owner.
    public let bakerAddress: AccountAddress
    /// The equity capital provided by the pool owner.
    public let bakerEquityCapital: CCD
    /// The capital delegated to the pool by other accounts.
    public let delegatedCapital: CCD
    /// The maximum amount that may be delegated to the pool, accounting for
    /// leverage and stake limits.
    public let delegatedCapitalCap: CCD
    /// The pool info associated with the pool: open status, metadata URL
    /// and commission rates.
    public let poolInfo: BakerPoolInfo
    /// Any pending change to the baker's stake.
    public let bakerStakePendingChange: PoolPendingChange
    /// Status of the pool in the current reward period. This will be [`None`]
    /// if the pool is not a baker in the payday (e.g., because they just
    /// registered and a new payday has not started yet).
    public let currentPaydayStatus: CurrentPaydayBakerPoolStatus?
    /// Total capital staked across all pools.
    public let allPoolTotalCapital: CCD
}

extension BakerPoolStatus: FromGRPC {
    typealias GRPC = Concordium_V2_PoolInfoResponse

    static func fromGRPC(_ g: GRPC) throws -> BakerPoolStatus {
        let currentPaydayStatus = g.hasCurrentPaydayInfo ? try CurrentPaydayBakerPoolStatus.fromGRPC(g.currentPaydayInfo) : nil
        return try Self(
            bakerId: g.baker.value,
            bakerAddress: .fromGRPC(g.address),
            bakerEquityCapital: .fromGRPC(g.equityCapital),
            delegatedCapital: .fromGRPC(g.delegatedCapital),
            delegatedCapitalCap: .fromGRPC(g.delegatedCapitalCap),
            poolInfo: .fromGRPC(g.poolInfo),
            bakerStakePendingChange: .fromGRPC(g.equityPendingChange),
            currentPaydayStatus: currentPaydayStatus,
            allPoolTotalCapital: .fromGRPC(g.allPoolTotalCapital)
        )
    }
}

extension Concordium_V2_BakerId {
    init(_ value: BakerID) {
        self.value = value
    }
}

extension Concordium_V2_PoolInfoRequest {
    init(bakerId: BakerID, block: BlockIdentifier) {
        baker = Concordium_V2_BakerId(bakerId)
        blockHash = block.toGRPC()
    }
}

/// State of the passive delegation pool at present. Changes to delegation
/// e.g., an account deciding to delegate are reflected in this structure at
/// first.
public struct PassiveDelegationStatus {
    /// The total capital delegated passively.
    public let delegatedCapital: CCD
    /// The passive delegation commission rates.
    public let commissionRates: CommissionRates
    /// The transaction fees accruing to the passive delegators in the
    /// current reward period.
    public let currentPaydayTransactionFeesEarned: CCD
    /// The effective delegated capital to the passive delegators for the
    /// current reward period.
    public let currentPaydayDelegatedCapital: CCD
    /// Total capital staked across all pools, including passive delegation.
    public let allPoolTotalCapital: CCD
}

extension PassiveDelegationStatus: FromGRPC {
    typealias GRPC = Concordium_V2_PassiveDelegationInfo

    static func fromGRPC(_ g: GRPC) throws -> PassiveDelegationStatus {
        try Self(
            delegatedCapital: .fromGRPC(g.delegatedCapital),
            commissionRates: .fromGRPC(g.commissionRates),
            currentPaydayTransactionFeesEarned: .fromGRPC(g.currentPaydayTransactionFeesEarned),
            currentPaydayDelegatedCapital: .fromGRPC(g.currentPaydayDelegatedCapital),
            allPoolTotalCapital: .fromGRPC(g.allPoolTotalCapital)
        )
    }
}
