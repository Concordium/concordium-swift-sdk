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

/// The possible events happening as a result of ``TransactionType.configureDelegation`` transaction
public enum DelegationEvent {
    case delegationAdded(delegatorId: AccountIndex)
    case delegationRemoved(delegatorId: AccountIndex)
    case delegationStakeIncreased(delegatorId: AccountIndex, newStake: CCD)
    case delegationStakeDecreased(delegatorId: AccountIndex, newStake: CCD)
    case delegationSetRestakeEarnings(delegatorId: AccountIndex, restakeEarnings: Bool)
    case delegationSetDelegationTarget(delegatorId: AccountIndex, delegationTarget: DelegationTarget)
}

/// The possible events happening as a result of ``TransactionType.configureBaker`` transaction
public enum BakerEvent {
    case bakerAdded(bakerId: AccountIndex)
    case bakerRemoved(bakerId: AccountIndex)
    case bakerStakeIncreased(bakerId: AccountIndex, newStake: CCD)
    case bakerStakeDecreased(bakerId: AccountIndex, newStake: CCD)
    case bakerSetRestakeEarnings(bakerId: AccountIndex, restakeEarnings: Bool)
    case bakerSetKeys(bakerId: AccountIndex, account: AccountAddress, signKey: Data, electionKey: Data, aggregationKey: Data)
    case bakerSetOpenStatus(bakerId: AccountIndex, openStatus: OpenStatus)
    case bakerSetMetadataUrl(bakerId: AccountIndex, metadataUrl: String)
    case bakerSetTransactionFeeCommission(bakerId: AccountIndex, commission: AmountFraction)
    case bakerSetBakingRewardCommission(bakerId: AccountIndex, commission: AmountFraction)
    case bakerSetFinalizationRewardCommission(bakerId: AccountIndex, commission: AmountFraction)
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

public struct EncryptedAmountRemovedEvent {
    public let account: AccountAddress
    public let newAmount: Data
    public let inputAmount: Data
    public let upToIndex: EncryptedAmountAggIndex
}