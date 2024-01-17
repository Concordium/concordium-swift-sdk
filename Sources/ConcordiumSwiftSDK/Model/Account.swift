import Base58Check
import Foundation

/// An account identifier used in queries.
public enum AccountIdentifier {
    /// Identify an account by an address.
    case address(AccountAddress)
    /// Identify an account by the credential registration id.
    case credentialRegistrationId(CredentialRegistrationId)
    /// Identify an account by its account index.
    case index(AccountIndex)

    func toGrpcType() -> Concordium_V2_AccountIdentifierInput {
        switch self {
        case let .address(addr):
            var a = Concordium_V2_AccountAddress()
            a.value = addr.bytes
            var i = Concordium_V2_AccountIdentifierInput()
            i.address = a
            return i
        case let .credentialRegistrationId(id):
            var c = Concordium_V2_CredentialRegistrationId()
            c.value = id
            var i = Concordium_V2_AccountIdentifierInput()
            i.credID = c
            return i
        case let .index(idx):
            var a = Concordium_V2_AccountIndex()
            a.value = idx
            var i = Concordium_V2_AccountIdentifierInput()
            i.accountIndex = a
            return i
        }
    }
}

/// Address of an account as raw bytes.
public struct AccountAddress {
    private static let base58CheckVersion: UInt8 = 1

    let bytes: Data // 32 bytes

    /// Construct address directly from a 32-byte data buffer.
    init(_ bytes: Data) {
        self.bytes = bytes
    }

    /// Construct address from the standard representation (Base58Check).
    init(base58Check: String) throws {
        var bytes = try Base58Check().decode(string: base58Check)
        let version = bytes.removeFirst()
        if version != AccountAddress.base58CheckVersion {
            throw GrpcError.unexpectedBase64CheckVersion(expected: AccountAddress.base58CheckVersion, actual: version)
        }
        self.bytes = bytes // excludes initial version byte
    }
}

/// A sequence number ordering transactions from a specific account.
/// The initial sequence number is `1`, and a transaction with sequence number `m` must be
/// followed by a transaction with sequence number `m+1`.
public typealias SequenceNumber = UInt64

public struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber?
    let allFinal: Bool
}

/// Index of the account in the account table.
/// These are assigned sequentially in the order of creation of accounts.
/// The first account has index 0.
public typealias AccountIndex = UInt64

/// A registration ID of a credential.
/// This ID is generated from the user's PRF key and a sequential counter.
/// ``CredentialRegistrationId``'s generated from the same PRF key,
/// but different counter values cannot easily be linked together.
public typealias CredentialRegistrationId = Data // 48 bytes

/// Amount of uCCD.
public typealias MicroCcdAmount = UInt64

/// Index of the credential that is to be used.
public typealias CredentialIndex = UInt32

/// Curve used by the anonymity revoker.
public typealias ArCurve = Data

/// Concrete attribute values.
/// All currently supported attributes are string values.
public typealias AttributeKind = Data

/// The minimum number of credentials that need to sign any transaction coming from an associated account.
public typealias AccountThreshold = UInt32

/// An ed25519 public key.
public typealias PublicKey = Data

func dateFromUnixTimeMillis(_ timestamp: UInt64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
}

/// An individual release of a locked balance.
public struct Release {
    /// Effective time of release.
    let timestamp: Date
    /// Amount to be released.
    let amount: MicroCcdAmount
    /// List of transaction hashes that contribute a balance to this release.
    let transactions: [TransactionHash]

    static func fromGrpcType(_ grpc: Concordium_V2_Release) -> Release {
        .init(
            timestamp: dateFromUnixTimeMillis(grpc.timestamp.value),
            amount: grpc.amount.value,
            transactions: grpc.transactions.map {
                $0.value
            }
        )
    }
}

/// State of the account's release schedule.
/// This is the balance of the account that is owned by the account, but cannot be used until the release point.
public struct ReleaseSchedule {
    /// Total amount that is locked up in releases.
    let total: MicroCcdAmount
    /// List of timestamped releases in increasing order of timestamps.
    let schedule: [Release]

    static func fromGrpcType(_ grpc: Concordium_V2_ReleaseSchedule) -> ReleaseSchedule {
        .init(total: grpc.total.value, schedule: grpc.schedules.map {
            .fromGrpcType($0)
        })
    }
}

public struct Versioned<V> {
    let version: UInt32
    let value: V
}

/// Index of an account key that is to be used.
public typealias KeyIndex = UInt32

/// The minimum number of signatures on a credential that need to sign any transaction coming from an associated account.
///
/// Accounts on Concordium consist of one or more credentials,
/// and each credential has one or more public keys, and its own threshold for how many of those credential's keys need to sign any valid message.
///
/// See ``AccountThreshold`` for the threshold of how many credentials need to sign a valid message.
public typealias SignatureThreshold = UInt32

/// A succinct identifier of an identity provider on the chain.
/// In credential deployments and other interactions with the chain, this is used to identify which identity provider is meant.
public typealias IpIdentity = UInt32

/// An abstraction of an attribute.
/// In the ID library internals the only thing we care about attributes is that they can be encoded as field elements.
/// The meaning of attributes is then assigned at the outer layers when the library is used.
public typealias AttributeTag = UInt32 // in Java SDK this is an public enum of 14 predefined values

/// Revealing threshold, i.e., degree of the polynomial + 1.
/// This value must always be at least 1.
public typealias Threshold = UInt32

/// Identity of the anonymity revoker on the chain.
/// This defines their evaluation point for secret sharing, and thus it cannot be 0.
public typealias ArIdentity = UInt32

/// Public AKA verification key for a given scheme. Currently only ed25519 is supported.
public enum VerifyKey {
    case Ed25519VerifyKey(PublicKey)

    static func fromGrpcType(_ grpc: Concordium_V2_AccountVerifyKey) -> VerifyKey? {
        switch grpc.key {
        case nil:
            return nil
        case let .ed25519Key(d):
            return .Ed25519VerifyKey(d)
        }
    }
}

/// Public credential keys currently on the account, together with the threshold
/// needed for a valid signature on a transaction.
public struct CredentialPublicKeys {
    let keys: [KeyIndex: VerifyKey]
    let threshold: SignatureThreshold

    static func fromGrpcType(_ grpc: Concordium_V2_CredentialPublicKeys) throws -> CredentialPublicKeys {
        try CredentialPublicKeys(
            keys: grpc.keys.mapValues {
                try VerifyKey.fromGrpcType($0) ?! GrpcError.requiredValueMissing("credential public keys")
            },
            threshold: grpc.threshold.value
        )
    }
}

/// YearMonth in Gregorian calendar.
/// The year is in Gregorian calendar and months are numbered from 1, i.e.,
/// 1 is January, ..., 12 is December.
/// Year must be a 4 digit year, i.e., between 1000 and 9999.
public struct YearMonth {
    let year: UInt32
    let month: UInt32

    static func fromGrpcType(_ grpc: Concordium_V2_YearMonth) -> YearMonth {
        YearMonth(year: grpc.year, month: grpc.month)
    }

    /// The string encoding (YYYYMM) used in JSON formats over FFI.
    var ffiJsonString: String {
        String(format: "%04d%02d", year, month)
    }
}

/// A policy is (currently) revealed values of attributes that are part of the
/// identity object. Policies are part of credentials.
public struct Policy<A> {
    let validTo: YearMonth
    let createdAt: YearMonth
    /// Revealed attributes.
    let policyVec: [AttributeTag: A]

    static func fromGrpcType(_ grpc: Concordium_V2_Policy) -> Policy<Data> {
        Policy<Data>(
            validTo: .fromGrpcType(grpc.validTo),
            createdAt: .fromGrpcType(grpc.createdAt),
            policyVec: grpc.attributes
        )
    }
}

/// Values in initial credential deployment.
public struct InitialCredentialDeploymentValues<C, A> {
    /// Account this credential belongs to.
    let credAccount: CredentialPublicKeys
    /// Credential registration id of the credential.
    let regId: C
    /// Identity of the identity provider who signed the identity object from which this credential is derived.
    let ipIdentity: IpIdentity
    /// Policy of this credential object.
    let policy: Policy<A>
}

/// Data relating to a single anonymity revoker sent by the account holder to the chain.
/// Typically a vector of these will be sent to the chain.
public typealias ChainArData<C> = Cipher<C>

/// Encrypted message.
public typealias Cipher<C> = C // in Rust SDK this is split into two values that each implement the "Curve" trait

/// Type of credential registration IDs.
public typealias CredId<C> = C // 48 bytes (according to Java SDK)

/// Values (as opposed to proofs) in credential deployment.
public struct CredentialDeploymentValues<C, A> {
    /// Credential keys (i.e. account holder keys).
    let credKeyInfo: CredentialPublicKeys
    /// Credential registration id of the credential.
    let credId: CredId<C>
    /// Identity of the identity provider who signed the identity object from which this credential is derived.
    let ipIdentity: IpIdentity
    /// Anonymity revocation threshold. Must be <= length of ar_data.
    let threshold: Threshold
    /// Anonymity revocation data. List of anonymity revokers which can revoke identity.
    /// NB: The order is important since it is the same order as that signed by the identity provider,
    ///  and permuting the list will invalidate the signature from the identity provider.
    let arData: [ArIdentity: ChainArData<C>]
    /// Policy of this credential object.
    let policy: Policy<A>
}

/// A Commitment is a group element.
public typealias PedersenCommitment<C> = C

public struct CredentialDeploymentCommitments<C> {
    /// Commitment to the PRF key.
    let prf: PedersenCommitment<C>
    /// Commitment to credential counter.
    let credCounter: PedersenCommitment<C>
    /// Commitment to the max account number.
    let maxAccounts: PedersenCommitment<C>
    /// List of commitments to the attributes that are not revealed.
    /// For the purposes of checking signatures,
    /// the commitments to those that are revealed as part of the policy are going to be computed by the verifier.
    let attributes: [AttributeTag: PedersenCommitment<C>]
    /// Commitments to the coefficients of the polynomial
    /// used to share `id_cred_sec`
    /// `S + b1 X + b2 X^2...`
    /// where `S` is `id_cred_sec`.
    let idCredSecSharingCoeff: [PedersenCommitment<C>]
}

/// Account credential with values and commitments, but without proofs.
/// Serialization must match the serializaiton of `AccountCredential` in Haskell.
public enum AccountCredentialWithoutProofs<C, A> {
    case initial(InitialCredentialDeploymentValues<C, A>)
    case normal(CredentialDeploymentValues<C, A>, CredentialDeploymentCommitments<C>)

    static func fromGrpcType(_ grpc: Concordium_V2_AccountCredential) throws -> AccountCredentialWithoutProofs<ArCurve, AttributeKind>? {
        switch grpc.credentialValues {
        case nil:
            return nil
        case let .initial(v):
            return try .initial(
                InitialCredentialDeploymentValues(
                    credAccount: .fromGrpcType(v.keys),
                    regId: v.credID.value,
                    ipIdentity: v.ipID.value,
                    policy: .fromGrpcType(v.policy)
                )
            )
        case let .normal(v):
            return try .normal(
                CredentialDeploymentValues(
                    credKeyInfo: .fromGrpcType(v.keys),
                    credId: v.credID.value,
                    ipIdentity: v.ipID.value,
                    threshold: v.arThreshold.value,
                    arData: v.arData.mapValues {
                        $0.encIDCredPubShare
                    },
                    policy: .fromGrpcType(v.policy)
                ),
                CredentialDeploymentCommitments(
                    prf: v.commitments.prf.value,
                    credCounter: v.commitments.credCounter.value,
                    maxAccounts: v.commitments.maxAccounts.value,
                    attributes: v.commitments.attributes.mapValues {
                        $0.value
                    },
                    idCredSecSharingCoeff: v.commitments.idCredSecSharingCoeff.map {
                        $0.value
                    }
                )
            )
        }
    }
}

public typealias EncryptedAmount<C> = C

public typealias AggregatedAmount = Data // in Rust/Java SDK this is (EncryptedAmount<ArCurve>, UInt32)

/// The state of the encrypted balance of an account.
public struct AccountEncryptedAmount {
    /// Encrypted amount that is a result of this accounts' actions.
    /// In particular this list includes the aggregate of
    ///
    /// - remaining amounts that result when transferring to public balance
    /// - remaining amounts when transferring to another account
    /// - encrypted amounts that are transferred from public balance
    ///
    /// When a transfer is made all of these must always be used.
    let selfAmount: EncryptedAmount<ArCurve>
    /// Starting index for incoming encrypted amounts.
    /// If an aggregated amount is present then this index is associated with such an amount
    /// and the list of incoming encrypted amounts starts at the index `start_index + 1`.
    let startIndex: UInt64
    /// If not nil, the amount that has resulted from aggregating other amounts
    /// and the number of aggregated amounts (must be at least 2 if present).
    let aggregatedAmount: AggregatedAmount?
    /// Amounts starting at `start_index` (or at `start_index + 1` if there is
    /// an aggregated amount present).
    /// They are assumed to be numbered sequentially.
    /// The length of this list is bounded by the maximum number of incoming amounts on the accounts, which is currently 32.
    /// After that aggregation kicks in.
    let incomingAmounts: [EncryptedAmount<ArCurve>]

    static func fromGrpcType(_ grpc: Concordium_V2_EncryptedBalance) -> AccountEncryptedAmount {
        AccountEncryptedAmount(
            selfAmount: grpc.selfAmount.value,
            startIndex: grpc.startIndex,
            aggregatedAmount: grpc.aggregatedAmount.value,
            incomingAmounts: grpc.incomingAmounts.map {
                $0.value
            }
        )
    }
}

/// An ed25519-like public key.
/// This has a bit stricter requirements than the signature scheme public keys.
/// In particular, points of small order are not allowed.
/// This is checked during serialization.
public typealias VrfPublicKey = PublicKey

public typealias Ed25519PublicKey = PublicKey

/// A Public Key is a point on the second curve of the pairing.
public typealias BlsPublicKey = PublicKey

/// A public key that corresponds to ``BakerElectionSignKey``.
public typealias BakerElectionVerifyKey = VrfPublicKey

/// A public key that corresponds to ``BakerSignatureSignKey``.
public typealias BakerSignatureVerifyKey = Ed25519PublicKey

/// Public key corresponding to ``BakerAggregationSignKey``.
public typealias BakerAggregationVerifyKey = BlsPublicKey

/// Internal short ID of the baker/validator.
public typealias BakerId = AccountIndex

/// Information about a baker/validator.
public struct BakerInfo {
    /// Identity of the baker. This is actually the account index of the account controlling the baker.
    let bakerId: BakerId
    /// Baker's public key used to check whether they won the lottery or not.
    let bakerElectionVerifyKey: BakerElectionVerifyKey
    /// Baker's public key used to check that they are indeed the ones who produced the block.
    let bakerSignatureVerifyKey: BakerSignatureVerifyKey
    /// Baker's public key used to check signatures on finalization records.
    /// This is only used if the baker has sufficient stake to participate in finalization.
    let bakerAggregationVerifyKey: BakerAggregationVerifyKey

    static func fromGrpcType(_ grpc: Concordium_V2_BakerInfo) -> BakerInfo {
        BakerInfo(
            bakerId: grpc.bakerID.value,
            bakerElectionVerifyKey: grpc.electionKey.value,
            bakerSignatureVerifyKey: grpc.signatureKey.value,
            bakerAggregationVerifyKey: grpc.aggregationKey.value
        )
    }
}

/// Pending change in the baker's stake.
public enum StakePendingChange {
    /// The stake is being reduced. The new stake will take affect in the given epoch.
    case reduceStake(newStake: MicroCcdAmount, effectiveTime: Date)
    /// The baker will be removed at the end of the given epoch.
    case removeStake(effectiveTime: Date)

    static func fromGrpcType(_ grpc: Concordium_V2_StakePendingChange) -> StakePendingChange? {
        switch grpc.change {
        case nil:
            return nil
        case let .reduce(r):
            return .reduceStake(newStake: r.newStake.value, effectiveTime: dateFromUnixTimeMillis(r.effectiveTime.value))
        case let .remove(r):
            return .removeStake(effectiveTime: dateFromUnixTimeMillis(r.value))
        }
    }
}

/// A fraction of an amount with a precision of 1/100000.
public struct AmountFraction {
    let partsPerHundredThousand: UInt32

    static func fromGrpcType(_ grpc: Concordium_V2_AmountFraction) -> AmountFraction {
        AmountFraction(partsPerHundredThousand: grpc.partsPerHundredThousand)
    }
}

/// Information about how open the pool is to new delegators.
public enum OpenStatus: Int {
    /// New delegators may join the pool.
    case openForAll = 0
    /// New delegators may not join, but existing delegators are kept.
    case closedForNew = 1
    /// No delegators are allowed.
    case closedForAll = 2

    static func fromGrpcType(_ grpc: Concordium_V2_OpenStatus) throws -> OpenStatus {
        try OpenStatus(rawValue: grpc.rawValue) ?! GrpcError.unsupportedValue("open status '\(grpc.rawValue)'")
    }
}

public struct CommissionRates {
    /// Fraction of finalization rewards charged by the pool owner.
    let finalization: AmountFraction?
    /// Fraction of baking rewards charged by the pool owner.
    let baking: AmountFraction?
    /// Fraction of transaction rewards charged by the pool owner.
    let transaction: AmountFraction?

    static func fromGrpcType(_ grpc: Concordium_V2_CommissionRates) -> CommissionRates {
        CommissionRates(
            finalization: grpc.hasFinalization ? .fromGrpcType(grpc.finalization) : nil,
            baking: grpc.hasBaking ? .fromGrpcType(grpc.baking) : nil,
            transaction: grpc.hasTransaction ? .fromGrpcType(grpc.transaction) : nil
        )
    }
}

/// Additional information about a baking pool.
/// This information is added with the introduction of delegation in protocol version 4.
public struct BakerPoolInfo {
    /// Whether the pool allows delegators.
    let openStatus: OpenStatus
    /// The URL that links to the metadata about the pool.
    let metadataUrl: String
    /// The commission rates charged by the pool owner.
    let commissionRates: CommissionRates

    static func fromGrpcType(_ grpc: Concordium_V2_BakerPoolInfo) throws -> BakerPoolInfo {
        try BakerPoolInfo(
            openStatus: .fromGrpcType(grpc.openStatus),
            metadataUrl: grpc.url,
            commissionRates: .fromGrpcType(grpc.commissionRates)
        )
    }
}

/// Target of delegation.
public enum DelegationTarget {
    /// Delegate passively, i.e., to no specific baker.
    case passive
    /// Delegate to a specific baker.
    case baker(BakerId)

    static func fromGrpcType(_ grpc: Concordium_V2_DelegationTarget) -> DelegationTarget? {
        switch grpc.target {
        case nil:
            return nil
        case .passive:
            return .passive
        case let .baker(b):
            return .baker(b.value)
        }
    }
}

public enum AccountStakingInfo {
    /// The account is a baker.
    case baker(
        stakedAmount: MicroCcdAmount,
        restakeEarnings: Bool,
        bakerInfo: BakerInfo,
        pendingChange: StakePendingChange?,
        poolInfo: BakerPoolInfo?
    )
    /// The account is delegating stake to a baker.
    case delegated(
        stakedAmount: MicroCcdAmount,
        restakeEarnings: Bool,
        delegationTarget: DelegationTarget,
        pendingChange: StakePendingChange?
    )

    static func fromGrpcType(_ grpc: Concordium_V2_AccountStakingInfo) throws -> AccountStakingInfo? {
        switch grpc.stakingInfo {
        case nil:
            return nil
        case let .baker(b):
            return try .baker(
                stakedAmount: b.stakedAmount.value,
                restakeEarnings: b.restakeEarnings,
                bakerInfo: .fromGrpcType(b.bakerInfo),
                pendingChange: .fromGrpcType(b.pendingChange),
                poolInfo: b.hasPoolInfo ? .fromGrpcType(b.poolInfo) : nil
            )
        case let .delegator(d):
            return try .delegated(
                stakedAmount: d.stakedAmount.value,
                restakeEarnings: d.restakeEarnings,
                delegationTarget: .fromGrpcType(d.target) ?! GrpcError.requiredValueMissing("delegation target"),
                pendingChange: .fromGrpcType(d.pendingChange)
            )
        }
    }
}

/// Elgamal public key.
public typealias ElgamalPublicKey = PublicKey

/// Information about the account at a particular point in time on chain.
public struct AccountInfo {
    /// Next sequence number to be used for transactions signed from this account.
    let sequenceNumber: SequenceNumber
    /// Current (unencrypted) balance of the account.
    let amount: MicroCcdAmount
    /// Release schedule for any locked up amount. This could be an empty release schedule.
    let releaseSchedule: ReleaseSchedule
    /// Map of all currently active credentials on the account.
    /// This includes public keys that can sign for the given credentials,
    /// as well as any revealed attributes.
    /// This map always contains a credential with index 0.
    let credentials: [CredentialIndex: Versioned<AccountCredentialWithoutProofs<ArCurve, AttributeKind>>]
    /// Lower bound on how many credentials must sign any given transaction from this account.
    let threshold: AccountThreshold
    /// The encrypted balance of the account.
    let encryptedAmount: AccountEncryptedAmount
    /// The public key for sending encrypted balances to the account.
    let encryptionKey: ElgamalPublicKey
    /// Internal index of the account.
    /// Accounts on the chain get sequential indices.
    /// These should generally not be used outside of the chain.
    /// The account address is meant to be used to refer to accounts,
    /// however the account index serves the role of the baker ID if the account is a baker.
    /// Hence it is exposed here as well.
    let index: AccountIndex
    /// Present if the account is a baker or delegator.
    /// In that case it is the information about the baker or delegator.
    let stake: AccountStakingInfo?
    /// Canonical address of the account.
    /// This is derived from the first credential that created the account.
    let address: AccountAddress

    static func fromGrpcType(_ grpc: Concordium_V2_AccountInfo) throws -> AccountInfo {
        try AccountInfo(
            sequenceNumber: grpc.sequenceNumber.value,
            amount: grpc.amount.value,
            releaseSchedule: .fromGrpcType(grpc.schedule),
            credentials: grpc.creds.mapValues {
                try Versioned(
                    version: 0, // mirroring Rust SDK
                    value: .fromGrpcType($0) ?! GrpcError.requiredValueMissing("credential values")
                )
            },
            threshold: grpc.threshold.value,
            encryptedAmount: AccountEncryptedAmount.fromGrpcType(grpc.encryptedBalance),
            encryptionKey: grpc.encryptionKey.value,
            index: grpc.index.value,
            stake: .fromGrpcType(grpc.stake),
            address: AccountAddress(grpc.address.value)
        )
    }
}
