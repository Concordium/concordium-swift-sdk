import Base58Check
import Foundation

enum AccountIdentifier {
    case address(AccountAddress)
    case credentialRegistrationId(CredentialRegistrationId)
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

private let accountAddressBase58CheckVersion: UInt8 = 1

struct AccountAddress {
    let bytes: Data // 32 bytes

    init(_ bytes: Data) {
        self.bytes = bytes
    }

    /// Construct address from the standard representation (Base58Check).
    init(base58Check: String) throws {
        var bytes = try Base58Check().decode(string: base58Check)
        let version = bytes.removeFirst()
        if version != accountAddressBase58CheckVersion {
            throw GrpcError.unexpectedBase64CheckVersion(expected: accountAddressBase58CheckVersion, actual: version)
        }
        self.bytes = bytes // excludes initial version byte
    }
}

typealias SequenceNumber = UInt64

struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber
    let allFinal: Bool
}

typealias AccountIndex = UInt64
typealias CredentialRegistrationId = Data // 48 bytes
typealias Amount = UInt64
typealias CredentialIndex = UInt32
typealias ArCurve = Data
typealias AttributeKind = Data
typealias AccountThreshold = UInt32
typealias AccountEncryptionKey = String
typealias PublicKey = Data

func dateFromUnixTimeMillis(_ timestamp: UInt64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
}

struct Release {
    let timestamp: Date
    let amount: Amount
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

struct AccountReleaseSchedule {
    let total: Amount
    let schedule: [Release]

    static func fromGrpcType(_ grpc: Concordium_V2_ReleaseSchedule) -> AccountReleaseSchedule {
        .init(total: grpc.total.value, schedule: grpc.schedules.map {
            .fromGrpcType($0)
        })
    }
}

struct Versioned<V> {
    let version: UInt32
    let value: V
}

typealias KeyIndex = UInt32
typealias VerifyKey = PublicKey
typealias SignatureThreshold = UInt32
typealias IpIdentity = UInt32
typealias AttributeTag = UInt32
typealias Threshold = UInt32
typealias ArIdentity = UInt32

extension VerifyKey {
    static func fromGrpcType(_ grpc: Concordium_V2_AccountVerifyKey) -> VerifyKey? {
        switch grpc.key {
        case nil:
            return nil
        case let .ed25519Key(d):
            return d
        }
    }
}

struct CredentialPublicKeys {
    let keys: [KeyIndex: VerifyKey]
    let threshold: SignatureThreshold

    static func fromGrpcType(_ grpc: Concordium_V2_CredentialPublicKeys) throws -> CredentialPublicKeys {
        try CredentialPublicKeys(
            keys: grpc.keys.mapValues {
                try VerifyKey.fromGrpcType($0) ?? {
                    throw GrpcError.requiredValueMissing("credential public keys")
                }()
            },
            threshold: grpc.threshold.value
        )
    }
}

struct YearMonth {
    let year: UInt32
    let month: UInt32

    static func fromGrpcType(_ grpc: Concordium_V2_YearMonth) -> YearMonth {
        YearMonth(year: grpc.year, month: grpc.month)
    }
}

struct Policy<A> {
    let validTo: YearMonth
    let policyVec: [AttributeTag: A]
}

struct InitialCredentialDeploymentValues<C, A> {
    let credAccount: CredentialPublicKeys
    let regId: C
    let ipIdentity: IpIdentity
    let policy: Policy<A>
}

typealias ChainArData<C> = Data // differs from Rust

struct CredentialDeploymentValues<C, A> {
    let credKeyInfo: CredentialPublicKeys
    let ipIdentity: IpIdentity
    let threshold: Threshold
    let arData: [ArIdentity: ChainArData<C>]
}

typealias PedersenCommitment<C> = C

struct CredentialDeploymentCommitments<C> {
    let cmmPrf: PedersenCommitment<C>
    let cmmCredCounter: PedersenCommitment<C>
    let cmmMaxAccounts: PedersenCommitment<C>
    let cmmAttributes: [AttributeTag: PedersenCommitment<C>]
    let cmmIdCredSecSharingCoeff: [PedersenCommitment<C>]
}

enum AccountCredentialWithoutProofs<C, A> {
    case initial(InitialCredentialDeploymentValues<C, A>)
    case normal(CredentialDeploymentValues<C, A>, CredentialDeploymentCommitments<C>)

    static func fromGrpcType(_ cred: Concordium_V2_AccountCredential) throws -> AccountCredentialWithoutProofs<ArCurve, AttributeKind>? {
        switch cred.credentialValues {
        case nil:
            return nil
        case let .initial(v):
            return try .initial(
                InitialCredentialDeploymentValues(
                    credAccount: .fromGrpcType(v.keys),
                    regId: v.credID.value,
                    ipIdentity: v.ipID.value,
                    policy: Policy(
                        validTo: .fromGrpcType(v.policy.validTo),
                        policyVec: v.policy.attributes
                    )
                )
            )
        case let .normal(v):
            return try .normal(
                CredentialDeploymentValues(
                    credKeyInfo: .fromGrpcType(v.keys),
                    ipIdentity: v.ipID.value,
                    threshold: v.arThreshold.value,
                    arData: v.arData.mapValues {
                        $0.encIDCredPubShare
                    }
                ),
                CredentialDeploymentCommitments(
                    cmmPrf: v.commitments.prf.value,
                    cmmCredCounter: v.commitments.credCounter.value,
                    cmmMaxAccounts: v.commitments.maxAccounts.value,
                    cmmAttributes: v.commitments.attributes.mapValues {
                        $0.value
                    },
                    cmmIdCredSecSharingCoeff: v.commitments.idCredSecSharingCoeff.map {
                        $0.value
                    }
                )
            )
        }
    }
}

typealias EncryptedAmount<C> = Data // is 'C' in Rust impl but the API returns Data

struct AccountEncryptedAmount {
    let selfAmount: EncryptedAmount<ArCurve>
    let startIndex: UInt64
    let aggregatedAmount: Data?
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

// TODO: Check out Java SDK for this...
typealias BakerElectionVerifyKey = PublicKey
typealias BakerSignatureVerifyKey = PublicKey
typealias BakerAggregationVerifyKey = PublicKey

typealias BakerId = AccountIndex

struct BakerInfo {
    let bakerId: BakerId
    let bakerElectionVerifyKey: BakerElectionVerifyKey
    let bakerSignatureVerifyKey: BakerSignatureVerifyKey
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

enum StakePendingChange {
    case reduceStake(newStake: Amount, effectiveTime: Date)
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

struct AmountFraction {
    let partsPerHundredThousand: UInt32

    static func fromGrpcType(_ grpc: Concordium_V2_AmountFraction) -> AmountFraction {
        AmountFraction(partsPerHundredThousand: grpc.partsPerHundredThousand)
    }
}

enum OpenStatus: Int {
    case openForAll = 0
    case closedForNew = 1
    case closedForAll = 2

    static func fromGrpcType(_ grpc: Concordium_V2_OpenStatus) -> OpenStatus {
        OpenStatus(rawValue: grpc.rawValue)!
    }
}

struct CommissionRates {
    let finalization: AmountFraction
    let baking: AmountFraction
    let transaction: AmountFraction

    static func fromGrpcType(_ grpc: Concordium_V2_CommissionRates) -> CommissionRates {
        CommissionRates(
            finalization: .fromGrpcType(grpc.finalization),
            baking: .fromGrpcType(grpc.baking),
            transaction: .fromGrpcType(grpc.transaction)
        )
    }
}

struct BakerPoolInfo {
    let openStatus: OpenStatus
    let metadataUrl: String
    let commissionRates: CommissionRates

    static func fromGrpcType(_ grpc: Concordium_V2_BakerPoolInfo) -> BakerPoolInfo {
        BakerPoolInfo(
            openStatus: .fromGrpcType(grpc.openStatus),
            metadataUrl: grpc.url,
            commissionRates: .fromGrpcType(grpc.commissionRates)
        )
    }
}

enum DelegationTarget {
    case passive
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

enum AccountStakingInfo {
    case baker(
        stakedAmount: Amount,
        restakeEarnings: Bool,
        bakerInfo: BakerInfo,
        pendingChange: StakePendingChange?,
        poolInfo: BakerPoolInfo?
    )
    case delegated(
        stakedAmount: Amount,
        restakeEarnings: Bool,
        delegationTarget: DelegationTarget,
        pendingChange: StakePendingChange?
    )

    static func fromGrpcType(_ grpc: Concordium_V2_AccountStakingInfo) throws -> AccountStakingInfo? {
        switch grpc.stakingInfo {
        case nil:
            return nil
        case let .baker(b):
            return .baker(
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
                delegationTarget: .fromGrpcType(d.target) ?? {
                    throw GrpcError.requiredValueMissing("delegation target")
                }(),
                pendingChange: .fromGrpcType(d.pendingChange)
            )
        }
    }
}

struct AccountInfo {
    let accountNonce: SequenceNumber
    let accountAmount: Amount
    let accountReleaseSchedule: AccountReleaseSchedule
    let accountCredentials: [CredentialIndex: Versioned<AccountCredentialWithoutProofs<ArCurve, AttributeKind>>]
    let accountThreshold: AccountThreshold
    let accountEncryptedAmount: AccountEncryptedAmount
    let accountEncryptionKey: PublicKey
    let accountIndex: AccountIndex
    let accountStake: AccountStakingInfo?
    let accountAddress: AccountAddress

    static func fromGrpcType(_ grpc: Concordium_V2_AccountInfo) throws -> AccountInfo {
        try AccountInfo(
            accountNonce: grpc.sequenceNumber.value,
            accountAmount: grpc.amount.value,
            accountReleaseSchedule: AccountReleaseSchedule.fromGrpcType(grpc.schedule),
            accountCredentials: grpc.creds.mapValues {
                try Versioned<AccountCredentialWithoutProofs<ArCurve, AttributeKind>>(
                    version: 0, // same as in Rust SDK
                    value: .fromGrpcType($0) ?? {
                        throw GrpcError.requiredValueMissing("credential values")
                    }()
                )
            },
            accountThreshold: grpc.threshold.value,
            accountEncryptedAmount: AccountEncryptedAmount.fromGrpcType(grpc.encryptedBalance),
            accountEncryptionKey: grpc.encryptionKey.value,
            accountIndex: grpc.index.value,
            accountStake: .fromGrpcType(grpc.stake),
            accountAddress: AccountAddress(grpc.address.value)
        )
    }
}
