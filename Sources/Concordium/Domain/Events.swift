import Foundation

/// Details of an account transaction. This always has a sender and is paid for,
/// and it might have some other effects on the state of the chain.
public struct AccountTransactionDetails {
    /// The amount of CCD the sender paid for including this transaction in
    /// the block.
    public let cost: CCD
    /// Sender of the transaction.
    public let sender: AccountAddress
    /// Effects of the account transaction, if any.
    public let effects: AccountTransactionEffects
}

extension AccountTransactionDetails: FromGRPC {
    typealias GRPC = Concordium_V2_AccountTransactionDetails

    static func fromGRPC(_ g: GRPC) throws -> AccountTransactionDetails {
        let cost = try CCD.fromGRPC(g.cost)
        let sender = AccountAddress.fromGRPC(g.sender)
        let effects = try AccountTransactionEffects.fromGRPC(g.effects)
        return Self(cost: cost, sender: sender, effects: effects)
    }
}

/// Effects of an account transactions. All variants apart from
/// [AccountTransactionEffects::None] correspond to a unique transaction that
/// was successful.
public enum AccountTransactionEffects {
    /// No effects other than payment from this transaction.
    /// The rejection reason indicates why the transaction failed.
    case none(transactionType: TransactionType?, rejectReason: RejectReason)
    case moduleDeployed(_ modRef: ModuleReference)
    case contractInitialized(_ event: ContractInitializedEvent)
    case contractUpdateIssued(effects: [ContractTraceElement])
    case accountTransfer(amount: CCD, to: AccountAddress, memo: Memo?)
    case bakerAdded // TODO: add details (not prioritized)
    case bakerRemoved // TODO: add details (not prioritized)
    case bakerStakeUpdated // TODO: add details (not prioritized)
    case bakerRestakeEarningsUpdated // TODO: add details (not prioritized)
    case bakerKeysUpdated // TODO: add details (not prioritized)
    case encryptedAmountTransferred // TODO: add details (not prioritized)
    case transferToEncrypted // TODO: add details (not prioritized)
    case transferToPublic(removed: EncryptedAmountRemovedEvent, amount: CCD)
    case transferredWithSchedule(to: AccountAddress, schedule: [ScheduledTransfer], memo: Memo?)
    case credentialKeysUpdated // TODO: add details (not prioritized)
    case credentialsUpdated // TODO: add details (not prioritized)
    case dataRegistered(_ data: RegisteredData)
    case bakerConfigured(events: [BakerEvent])
    case delegationConfigured(events: [DelegationEvent])
}

extension AccountTransactionEffects: FromGRPC {
    typealias GRPC = Concordium_V2_AccountTransactionEffects

    static func fromGRPC(_ g: GRPC) throws -> AccountTransactionEffects {
        let effects = try g.effect ?! GRPCError.missingRequiredValue("Missing 'effect' in 'AccountTransactionEffects'")
        switch effects {
        case let .none(v):
            let transactionType = v.hasTransactionType ? try TransactionType.fromGRPC(v.transactionType) : nil
            let rejectReason = try RejectReason.fromGRPC(v.rejectReason)
            return .none(transactionType: transactionType, rejectReason: rejectReason)
        case let .accountTransfer(v):
            let memo = v.hasMemo ? try Memo.fromGRPC(v.memo) : nil
            return try .accountTransfer(amount: .fromGRPC(v.amount), to: .fromGRPC(v.receiver), memo: memo)
        case .bakerAdded:
            return .bakerAdded
        case let .bakerConfigured(data):
            let events = try data.events.map { try BakerEvent.fromGRPC($0) }
            return .bakerConfigured(events: events)
        case .bakerKeysUpdated:
            return .bakerKeysUpdated
        case .bakerRemoved:
            return .bakerRemoved
        case .bakerRestakeEarningsUpdated:
            return .bakerRestakeEarningsUpdated
        case .bakerStakeUpdated:
            return .bakerStakeUpdated
        case let .contractInitialized(data):
            return try .contractInitialized(.fromGRPC(data))
        case let .contractUpdateIssued(data):
            let effects = try data.effects.map { try ContractTraceElement.fromGRPC($0) }
            return .contractUpdateIssued(effects: effects)
        case .credentialKeysUpdated:
            return .credentialKeysUpdated
        case .credentialsUpdated:
            return .credentialsUpdated
        case let .dataRegistered(data):
            return try .dataRegistered(.fromGRPC(data))
        case let .delegationConfigured(data):
            let events = try data.events.map { try DelegationEvent.fromGRPC($0) }
            return .delegationConfigured(events: events)
        case .encryptedAmountTransferred:
            return .encryptedAmountTransferred
        case let .moduleDeployed(modRef):
            return try .moduleDeployed(.fromGRPC(modRef))
        case .transferredToEncrypted:
            return .transferToEncrypted
        case let .transferredToPublic(data):
            return try .transferToPublic(removed: .fromGRPC(data.removed), amount: .fromGRPC(data.amount))
        case let .transferredWithSchedule(data):
            let schedule = try data.amount.map { try ScheduledTransfer.fromGRPC($0) }
            let memo = data.hasMemo ? try Memo.fromGRPC(data.memo) : nil
            return .transferredWithSchedule(to: .fromGRPC(data.receiver), schedule: schedule, memo: memo)
        }
    }
}

/// The possible events happening as a result of ``TransactionType.configureDelegation`` transaction
public enum DelegationEvent {
    case delegationAdded(delegatorId: AccountIndex)
    case delegationRemoved(delegatorId: AccountIndex)
    case delegationStakeIncreased(delegatorId: AccountIndex, newStake: CCD)
    case delegationStakeDecreased(delegatorId: AccountIndex, newStake: CCD)
    case delegationSetRestakeEarnings(delegatorId: AccountIndex, restakeEarnings: Bool)
    case delegationSetDelegationTarget(delegatorId: AccountIndex, delegationTarget: DelegationTarget)
}

extension DelegationEvent: FromGRPC {
    typealias GRPC = Concordium_V2_DelegationEvent

    static func fromGRPC(_ g: GRPC) throws -> DelegationEvent {
        let event = try g.event ?! GRPCError.missingRequiredValue("event")
        switch event {
        case let .delegationAdded(id):
            return .delegationAdded(delegatorId: id.id.value)
        case let .delegationRemoved(id):
            return .delegationRemoved(delegatorId: id.id.value)
        case let .delegationSetDelegationTarget(data):
            return try .delegationSetDelegationTarget(delegatorId: data.delegatorID.id.value, delegationTarget: .fromGRPC(data.delegationTarget))
        case let .delegationSetRestakeEarnings(data):
            return .delegationSetRestakeEarnings(delegatorId: data.delegatorID.id.value, restakeEarnings: data.restakeEarnings)
        case let .delegationStakeDecreased(data):
            return try .delegationStakeDecreased(delegatorId: data.delegatorID.id.value, newStake: .fromGRPC(data.newStake))
        case let .delegationStakeIncreased(data):
            return try .delegationStakeIncreased(delegatorId: data.delegatorID.id.value, newStake: .fromGRPC(data.newStake))
        }
    }
}

public struct BakerKeysEvent {
    /// ID of the baker whose keys were changed.
    public let bakerId: AccountIndex
    /// Account address of the baker.
    public let account: AccountAddress
    /// The new public key for verifying block signatures.
    public let signKey: BakerSignatureVerifyKey
    /// The new public key for verifying whether the baker won the block
    /// lottery.
    public let electionKey: BakerElectionVerifyKey
    /// The new public key for verifying finalization records.
    public let aggregationKey: BakerAggregationVerifyKey
}

extension BakerKeysEvent: FromGRPC {
    typealias GRPC = Concordium_V2_BakerKeysEvent

    static func fromGRPC(_ g: GRPC) -> BakerKeysEvent {
        .init(bakerId: g.bakerID.value, account: .fromGRPC(g.account), signKey: g.signKey.value, electionKey: g.electionKey.value, aggregationKey: g.aggregationKey.value)
    }
}

/// The possible events happening as a result of ``TransactionType.configureBaker`` transaction
public enum BakerEvent {
    case bakerAdded(keys: BakerKeysEvent, stake: CCD, restakeEarnings: Bool)
    case bakerRemoved(bakerId: AccountIndex)
    case bakerStakeIncreased(bakerId: AccountIndex, newStake: CCD)
    case bakerStakeDecreased(bakerId: AccountIndex, newStake: CCD)
    case bakerSetRestakeEarnings(bakerId: AccountIndex, restakeEarnings: Bool)
    case bakerSetKeys(_ keys: BakerKeysEvent)
    case bakerSetOpenStatus(bakerId: AccountIndex, openStatus: OpenStatus)
    case bakerSetMetadataUrl(bakerId: AccountIndex, metadataUrl: String)
    case bakerSetTransactionFeeCommission(bakerId: AccountIndex, commission: AmountFraction)
    case bakerSetBakingRewardCommission(bakerId: AccountIndex, commission: AmountFraction)
    case bakerSetFinalizationRewardCommission(bakerId: AccountIndex, commission: AmountFraction)
}

extension BakerEvent: FromGRPC {
    typealias GRPC = Concordium_V2_BakerEvent

    static func fromGRPC(_ g: GRPC) throws -> BakerEvent {
        let event = try g.event ?! GRPCError.missingRequiredValue("event")
        switch event {
        case let .bakerAdded(data):
            return try .bakerAdded(keys: .fromGRPC(data.keysEvent), stake: .fromGRPC(data.stake), restakeEarnings: data.restakeEarnings)
        case let .bakerRemoved(id):
            return .bakerRemoved(bakerId: id.value)
        case let .bakerRestakeEarningsUpdated(data):
            return .bakerSetRestakeEarnings(bakerId: data.bakerID.value, restakeEarnings: data.restakeEarnings)
        case let .bakerStakeDecreased(data):
            return try .bakerStakeDecreased(bakerId: data.bakerID.value, newStake: .fromGRPC(data.newStake))
        case let .bakerStakeIncreased(data):
            return try .bakerStakeIncreased(bakerId: data.bakerID.value, newStake: .fromGRPC(data.newStake))
        case let .bakerKeysUpdated(keys):
            return .bakerSetKeys(.fromGRPC(keys))
        case let .bakerSetBakingRewardCommission(data):
            return .bakerSetBakingRewardCommission(bakerId: data.bakerID.value, commission: .fromGRPC(data.bakingRewardCommission))
        case let .bakerSetFinalizationRewardCommission(data):
            return .bakerSetFinalizationRewardCommission(bakerId: data.bakerID.value, commission: .fromGRPC(data.finalizationRewardCommission))
        case let .bakerSetTransactionFeeCommission(data):
            return .bakerSetTransactionFeeCommission(bakerId: data.bakerID.value, commission: .fromGRPC(data.transactionFeeCommission))
        case let .bakerSetOpenStatus(data):
            return try .bakerSetOpenStatus(bakerId: data.bakerID.value, openStatus: .fromGRPC(data.openStatus))
        case let .bakerSetMetadataURL(data):
            return .bakerSetMetadataUrl(bakerId: data.bakerID.value, metadataUrl: data.url)
        }
    }
}

/// A reason for why a transaction was rejected. Rejected means included in a
/// block, but the desired action was not achieved. The only effect of a
/// rejected transaction is payment.
public enum RejectReason {
    /// Error raised when validating the Wasm module.
    case moduleNotWF
    /// As the name says.
    case moduleHashAlreadyExists(contents: ModuleReference)
    /// Account does not exist.
    case invalidAccountReference(contents: AccountAddress)
    /// Reference to a non-existing contract init method.
    case invalidInitMethod(contents: (modRef: ModuleReference, initName: InitName))
    /// Reference to a non-existing contract receive method.
    case invalidReceiveMethod(contents: (modRef: ModuleReference, receiveName: ReceiveName))
    /// Reference to a non-existing module.
    case invalidModuleReference(contents: ModuleReference)
    /// Contract instance does not exist.
    case invalidContractAddress(contents: ContractAddress)
    /// Runtime exception occurred when running either the init or receive
    /// method.
    case runtimeFailure
    /// When one wishes to transfer an amount from A to B but there
    /// are not enough funds on account/contract A to make this
    /// possible. The data are the from address and the amount to transfer.
    case amountTooLarge(contents: (address: Address, amount: CCD))
    /// Serialization of the body failed.
    case serializationFailure
    /// We ran of out energy to process this transaction.
    case outOfEnergy
    /// Rejected due to contract logic in init function of a contract.
    case rejectedInit(reject_reason: Int32)
    case rejectedReceive(
        reject_reason: Int32,
        contract_address: ContractAddress,
        receive_name: ReceiveName,
        parameter: Parameter
    )
    /// Proof that the baker owns relevant private keys is not valid.
    case invalidProof
    /// Tried to add baker for an account that already has a baker
    case alreadyABaker(contents: BakerID)
    /// Tried to remove a baker for an account that has no baker
    case notABaker(contents: AccountAddress)
    /// The amount on the account was insufficient to cover the proposed stake
    case insufficientBalanceForBakerStake
    /// The amount provided is under the threshold required for becoming a baker
    case stakeUnderMinimumThresholdForBaking
    /// The change could not be made because the baker is in cooldown for
    /// another change
    case bakerInCooldown
    /// A baker with the given aggregation key already exists
    case duplicateAggregationKey(contents: BakerAggregationVerifyKey)
    /// Encountered credential ID that does not exist
    case nonExistentCredentialID
    /// Attempted to add an account key to a key index already in use
    case keyIndexAlreadyInUse
    /// When the account threshold is updated, it must not exceed the amount of
    /// existing keys
    case invalidAccountThreshold
    /// When the credential key threshold is updated, it must not exceed the
    /// amount of existing keys
    case invalidCredentialKeySignThreshold
    /// Proof for an encrypted amount transfer did not validate.
    case invalidEncryptedAmountTransferProof
    /// Proof for a secret to public transfer did not validate.
    case invalidTransferToPublicProof
    /// Account tried to transfer an encrypted amount to itself, that's not
    /// allowed.
    case encryptedAmountSelfTransfer(contents: AccountAddress)
    /// The provided index is below the start index or above `startIndex +
    /// length incomingAmounts`
    case invalidIndexOnEncryptedTransfer
    /// The transfer with schedule is going to send 0 tokens
    case zeroScheduledAmount
    /// The transfer with schedule has a non strictly increasing schedule
    case nonIncreasingSchedule
    /// The first scheduled release in a transfer with schedule has already
    /// expired
    case firstScheduledReleaseExpired
    /// Account tried to transfer with schedule to itself, that's not allowed.
    case scheduledSelfTransfer(contents: AccountAddress)
    /// At least one of the credentials was either malformed or its proof was
    /// incorrect.
    case invalidCredentials
    /// Some of the credential IDs already exist or are duplicated in the
    /// transaction.
    case duplicateCredIDs(contents: [CredentialRegistrationID])
    /// A credential id that was to be removed is not part of the account.
    case nonExistentCredIDs(contents: [CredentialRegistrationID])
    /// Attemp to remove the first credential
    case removeFirstCredential
    /// The credential holder of the keys to be updated did not sign the
    /// transaction
    case credentialHolderDidNotSign
    /// Account is not allowed to have multiple credentials because it contains
    /// a non-zero encrypted transfer.
    case notAllowedMultipleCredentials
    /// The account is not allowed to receive encrypted transfers because it has
    /// multiple credentials.
    case notAllowedToReceiveEncrypted
    /// The account is not allowed to send encrypted transfers (or transfer
    /// from/to public to/from encrypted)
    case notAllowedToHandleEncrypted
    /// A configure baker transaction is missing one or more arguments in order
    /// to add a baker.
    case missingBakerAddParameters
    /// Finalization reward commission is not in the valid range for a baker
    case finalizationRewardCommissionNotInRange
    /// Baking reward commission is not in the valid range for a baker
    case bakingRewardCommissionNotInRange
    /// Transaction fee commission is not in the valid range for a baker
    case transactionFeeCommissionNotInRange
    /// Tried to add baker for an account that already has a delegator.
    case alreadyADelegator
    /// The amount on the account was insufficient to cover the proposed stake.
    case insufficientBalanceForDelegationStake
    /// A configure delegation transaction is missing one or more arguments in
    /// order to add a delegator.
    case missingDelegationAddParameters
    /// Delegation stake when adding a delegator was 0.
    case insufficientDelegationStake
    /// Account is not a delegation account.
    case delegatorInCooldown
    /// Account is not a delegation account.
    case notADelegator(contents: AccountAddress)
    /// Delegation target is not a baker
    case delegationTargetNotABaker(contents: BakerID)
    /// The amount would result in pool capital higher than the maximum
    /// threshold.
    case stakeOverMaximumThresholdForPool
    /// The amount would result in pool with a too high fraction of delegated
    /// capital.
    case poolWouldBecomeOverDelegated
    /// The pool is not open to delegators.
    case poolClosed
}

extension RejectReason: FromGRPC {
    typealias GRPC = Concordium_V2_RejectReason

    static func fromGRPC(_ g: GRPC) throws -> RejectReason {
        let reason = try g.reason ?! GRPCError.missingRequiredValue("Missing 'reason' of value")
        switch reason {
        case let .alreadyABaker(v):
            return .alreadyABaker(contents: v.value)
        case .alreadyADelegator:
            return .alreadyADelegator
        case let .amountTooLarge(v):
            return try .amountTooLarge(contents: (address: .fromGRPC(v.address), amount: .fromGRPC(v.amount)))
        case .bakerInCooldown:
            return .bakerInCooldown
        case .bakingRewardCommissionNotInRange:
            return .bakingRewardCommissionNotInRange
        case .credentialHolderDidNotSign:
            return .credentialHolderDidNotSign
        case let .delegationTargetNotABaker(v):
            return .delegationTargetNotABaker(contents: v.value)
        case .delegatorInCooldown:
            return .delegatorInCooldown
        case let .duplicateAggregationKey(v):
            return .duplicateAggregationKey(contents: v.value)
        case let .duplicateCredIds(v):
            return try .duplicateCredIDs(contents: v.ids.map { try .fromGRPC($0) })
        case let .encryptedAmountSelfTransfer(v):
            return .encryptedAmountSelfTransfer(contents: .fromGRPC(v))
        case .finalizationRewardCommissionNotInRange:
            return .finalizationRewardCommissionNotInRange
        case .firstScheduledReleaseExpired:
            return .firstScheduledReleaseExpired
        case .insufficientBalanceForBakerStake:
            return .insufficientBalanceForBakerStake
        case .insufficientBalanceForDelegationStake:
            return .insufficientBalanceForDelegationStake
        case .insufficientDelegationStake:
            return .insufficientDelegationStake
        case let .invalidAccountReference(v):
            return .invalidAccountReference(contents: .fromGRPC(v))
        case .invalidAccountThreshold:
            return .invalidAccountThreshold
        case let .invalidContractAddress(v):
            return .invalidContractAddress(contents: .fromGRPC(v))
        case .invalidCredentialKeySignThreshold:
            return .invalidCredentialKeySignThreshold
        case .invalidCredentials:
            return .invalidCredentials
        case .invalidEncryptedAmountTransferProof:
            return .invalidEncryptedAmountTransferProof
        case .invalidIndexOnEncryptedTransfer:
            return .invalidIndexOnEncryptedTransfer
        case let .invalidInitMethod(v):
            return try .invalidInitMethod(contents: (modRef: .fromGRPC(v.moduleRef), initName: .fromGRPC(v.initName)))
        case let .invalidModuleReference(v):
            return try .invalidModuleReference(contents: .fromGRPC(v))
        case .invalidProof:
            return .invalidProof
        case let .invalidReceiveMethod(v):
            return try .invalidReceiveMethod(contents: (modRef: .fromGRPC(v.moduleRef), receiveName: .fromGRPC(v.receiveName)))
        case .invalidTransferToPublicProof:
            return .invalidTransferToPublicProof
        case .keyIndexAlreadyInUse:
            return .keyIndexAlreadyInUse
        case .missingBakerAddParameters:
            return .missingBakerAddParameters
        case .missingDelegationAddParameters:
            return .missingDelegationAddParameters
        case let .moduleHashAlreadyExists(v):
            return try .moduleHashAlreadyExists(contents: .fromGRPC(v))
        case .moduleNotWf:
            return .moduleNotWF
        case let .nonExistentCredIds(v):
            return try .nonExistentCredIDs(contents: v.ids.map { try .fromGRPC($0) })
        case .nonExistentCredentialID:
            return .nonExistentCredentialID
        case .nonIncreasingSchedule:
            return .nonIncreasingSchedule
        case let .notABaker(v):
            return .notABaker(contents: .fromGRPC(v))
        case let .notADelegator(v):
            return .notADelegator(contents: .fromGRPC(v))
        case .notAllowedMultipleCredentials:
            return .notAllowedMultipleCredentials
        case .notAllowedToHandleEncrypted:
            return .notAllowedToHandleEncrypted
        case .notAllowedToReceiveEncrypted:
            return .notAllowedToReceiveEncrypted
        case .outOfEnergy:
            return .outOfEnergy
        case .poolClosed:
            return .poolClosed
        case .poolWouldBecomeOverDelegated:
            return .poolWouldBecomeOverDelegated
        case let .rejectedInit(v):
            return .rejectedInit(reject_reason: v.rejectReason)
        case let .rejectedReceive(v):
            return try .rejectedReceive(reject_reason: v.rejectReason, contract_address: .fromGRPC(v.contractAddress), receive_name: .fromGRPC(v.receiveName), parameter: .fromGRPC(v.parameter))
        case .removeFirstCredential:
            return .removeFirstCredential
        case .runtimeFailure:
            return .runtimeFailure
        case let .scheduledSelfTransfer(v):
            return .scheduledSelfTransfer(contents: .fromGRPC(v))
        case .serializationFailure:
            return .serializationFailure
        case .stakeOverMaximumThresholdForPool:
            return .stakeOverMaximumThresholdForPool
        case .stakeUnderMinimumThresholdForBaking:
            return .stakeUnderMinimumThresholdForBaking
        case .transactionFeeCommissionNotInRange:
            return .transactionFeeCommissionNotInRange
        case .zeroScheduledAmount:
            return .zeroScheduledAmount
        }
    }
}

public struct ContractInitializedEvent {
    /// The WASM version of the contract
    public let contractVersion: WasmVersion
    /// The origin module reference containing the source code of the contract
    public let ref: ModuleReference
    /// The contract address where the contract is available
    public let address: ContractAddress
    /// The amount of CCD the instance was initialized with
    public let amount: CCD
    /// The ``InitName`` of the contract, i.e. in the `init_<contract-name>` format
    public let initName: InitName
    /// Events generated during contract initialization
    public let events: [ContractEvent]
}

extension ContractInitializedEvent: FromGRPC {
    typealias GRPC = Concordium_V2_ContractInitializedEvent

    static func fromGRPC(_ g: GRPC) throws -> ContractInitializedEvent {
        let events = try g.events.map { try ContractEvent.fromGRPC($0) }
        return try .init(contractVersion: .fromGRPC(g.contractVersion), ref: .fromGRPC(g.originRef), address: .fromGRPC(g.address), amount: .fromGRPC(g.amount), initName: .fromGRPC(g.initName), events: events)
    }
}

/// A successful contract invocation produces a sequence of effects on smart
/// contracts and possibly accounts (if any contract transfers CCD to an
/// account).
public enum ContractTraceElement {
    /// A contract instance was updated
    case updated(contractVersion: WasmVersion, address: ContractAddress, instigator: Address, amount: CCD, message: Parameter, receiveName: ReceiveName, events: [ContractEvent])
    /// A contract transferred an amount to an account
    case transferred(from: ContractAddress, to: AccountAddress, amount: CCD)
    /// Contract instance execution interrupted
    case interrupted(address: ContractAddress, events: [ContractEvent])
    /// Contract instance execution resumed
    case resumed(address: ContractAddress, success: Bool)
    /// Contract instance was upgraded from one module to another
    case upgraded(address: ContractAddress, from: ModuleReference, to: ModuleReference)
}

extension ContractTraceElement: FromGRPC {
    typealias GRPC = Concordium_V2_ContractTraceElement

    static func fromGRPC(_ g: GRPC) throws -> ContractTraceElement {
        let value = try g.element ?! GRPCError.missingRequiredValue("element")
        switch value {
        case let .updated(data):
            let events = try data.events.map { try ContractEvent.fromGRPC($0) }
            return try .updated(contractVersion: .fromGRPC(data.contractVersion), address: .fromGRPC(data.address), instigator: .fromGRPC(data.instigator), amount: .fromGRPC(data.amount), message: .fromGRPC(data.parameter), receiveName: .fromGRPC(data.receiveName), events: events)
        case let .interrupted(data):
            let events = try data.events.map { try ContractEvent.fromGRPC($0) }
            return .interrupted(address: .fromGRPC(data.address), events: events)
        case let .resumed(data):
            return .resumed(address: .fromGRPC(data.address), success: data.success)
        case let .transferred(data):
            return try .transferred(from: .fromGRPC(data.sender), to: .fromGRPC(data.receiver), amount: .fromGRPC(data.amount))
        case let .upgraded(data):
            return try .upgraded(address: .fromGRPC(data.address), from: .fromGRPC(data.from), to: .fromGRPC(data.to))
        }
    }
}

public struct EncryptedAmountRemovedEvent {
    public let account: AccountAddress
    public let newAmount: Data
    public let inputAmount: Data
    public let upToIndex: EncryptedAmountAggIndex
}

extension EncryptedAmountRemovedEvent: FromGRPC {
    typealias GRPC = Concordium_V2_EncryptedAmountRemovedEvent

    static func fromGRPC(_ g: GRPC) throws -> EncryptedAmountRemovedEvent {
        .init(account: .fromGRPC(g.account), newAmount: g.newAmount.value, inputAmount: g.inputAmount.value, upToIndex: g.upToIndex)
    }
}
