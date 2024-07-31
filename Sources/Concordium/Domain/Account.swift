import Base58Check
import ConcordiumWalletCrypto
import Foundation
import NIO

/// Index of an account in the account table.
/// These are assigned sequentially in the order of creation of accounts.
/// The first account has index 0.
public typealias AccountIndex = UInt64

/// Internal short ID of the baker/validator.
public typealias BakerID = AccountIndex

/// Index of the credential that is to be used.
public typealias CredentialIndex = UInt32

/// Index of an account key that is to be used.
public typealias KeyIndex = UInt8

public enum CredentialRegistrationIDError: Error {
    case unexpectedSize(actual: Int)
    case invalid(String)
}

/// A registration ID of a credential.
/// This ID is generated from the user's PRF key and a sequential counter.
/// ``CredentialRegistrationID``'s generated from the same PRF key,
/// but different counter values cannot easily be linked together.
/// - Throws: ``CredentialRegistrationIDError``
public struct CredentialRegistrationID: Serialize, Deserialize, FromGRPC, ToGRPC, Equatable {
    public static let SIZE: UInt8 = 48
    typealias GRPC = Concordium_V2_CredentialRegistrationId
    public let value: Data // 48 bytes

    public init(_ value: Data) throws {
        guard value.count == Self.SIZE else { throw CredentialRegistrationIDError.unexpectedSize(actual: value.count) }
        guard value.first! >> 7 == 1 else { throw CredentialRegistrationIDError.invalid("Expected first bit in data to be 1") }
        self.value = value
    }

    static func fromGRPC(_ gRPC: Concordium_V2_CredentialRegistrationId) throws -> CredentialRegistrationID {
        try Self(gRPC.value)
    }

    func toGRPC() -> Concordium_V2_CredentialRegistrationId {
        var g = GRPC()
        g.value = value
        return g
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> CredentialRegistrationID? {
        guard let value = data.read(num: SIZE) else { return nil }
        return try? Self(value)
    }
}

/// A succinct identifier of an identity provider on the chain.
/// In credential deployments and other interactions with the chain, this is used to identify which identity provider is meant.
public typealias IdentityProviderID = UInt32

/// Identity of an anonymity revoker on the chain.
/// This defines their evaluation point for secret sharing, and thus it cannot be 0.
public typealias AnonymityRevokerID = UInt32

/// The minimum number of signatures on a credential that need to sign any transaction coming from an associated account.
public typealias SignatureThreshold = UInt8

/// Revealing threshold, i.e., degree of the polynomial + 1.
/// This value must always be at least 1.
public typealias RevocationThreshold = UInt8

/// Amount of uCCD.
public typealias MicroCCDAmount = UInt64

public typealias EncryptedAmount = Data

public typealias AggregatedAmount = Data // in Rust/Java SDK this is (EncryptedAmount<ArCurve>, UInt32)

/// An Ed25519-like public key.
public typealias VRFPublicKey = String

public typealias Ed25519PublicKey = String

public typealias BLSPublicKey = String

/// Elgamal public key.
public typealias ElgamalPublicKey = String

/// A public key that corresponds to ``BakerElectionSignKey``.
public typealias BakerElectionVerifyKey = VRFPublicKey

/// A public key that corresponds to ``BakerSignatureSignKey``.
public typealias BakerSignatureVerifyKey = Ed25519PublicKey

/// Public key corresponding to ``BakerAggregationSignKey``.
public typealias BakerAggregationVerifyKey = BLSPublicKey

/// An account identifier used in queries.
public enum AccountIdentifier: ToGRPC {
    /// Identify an account by an address.
    case address(AccountAddress)
    /// Identify an account by the credential registration id.
    case credentialRegistrationID(CredentialRegistrationID)
    /// Identify an account by its account index.
    case index(AccountIndex)

    func toGRPC() -> Concordium_V2_AccountIdentifierInput {
        switch self {
        case let .address(addr):
            var i = Concordium_V2_AccountIdentifierInput()
            i.address = addr.toGRPC()
            return i
        case let .credentialRegistrationID(id):
            var i = Concordium_V2_AccountIdentifierInput()
            i.credID = id.toGRPC()
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
public struct AccountAddress: Hashable, Serialize, Deserialize, ToGRPC, FromGRPC {
    public static let SIZE: UInt8 = 32
    func toGRPC() -> Concordium_V2_AccountAddress {
        var g = GRPC()
        g.value = data
        return g
    }

    typealias GRPC = Concordium_V2_AccountAddress

    private static let base58CheckVersion: UInt8 = 1

    public var data: Data // 32 bytes

    public var base58Check: String {
        var versionedData = Data([Self.base58CheckVersion])
        versionedData.append(data)
        return Base58Check().encode(data: versionedData)
    }

    /// Construct address directly from a 32-byte data buffer.
    public init(_ data: Data) {
        self.data = data
    }

    /// Construct address from the standard representation (Base58Check).
    public init(base58Check: String) throws {
        var data = try Base58Check().decode(string: base58Check)
        let version = data.removeFirst()
        if version != Self.base58CheckVersion {
            throw GRPCError.unexpectedBase58CheckVersion(expected: Self.base58CheckVersion, actual: version)
        }
        self.init(data) // excludes initial version byte
    }

    public static func deserialize(_ data: inout Cursor) -> AccountAddress? {
        data.read(num: SIZE).map { AccountAddress(Data($0)) }
    }

    static func fromGRPC(_ grpc: GRPC) -> Self {
        .init(grpc.value)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(data)
    }
}

/// A sequence number ordering transactions from a specific account.
/// The initial sequence number is `1`, and a transaction with sequence number `m` must be
/// followed by a transaction with sequence number `m+1`.
public typealias SequenceNumber = UInt64

public struct NextAccountSequenceNumber: FromGRPC {
    public var sequenceNumber: SequenceNumber
    public var allFinal: Bool

    static func fromGRPC(_ grpc: Concordium_V2_NextAccountSequenceNumber) -> Self {
        .init(
            sequenceNumber: grpc.sequenceNumber.value,
            allFinal: grpc.allFinal
        )
    }
}

func dateFromUnixTimeMillis(_ timestamp: UInt64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
}

/// An individual release of a locked balance.
public struct Release: FromGRPC {
    /// Effective time of release.
    public var timestamp: Date
    /// Amount to be released.
    public var amount: MicroCCDAmount
    /// List of transaction hashes that contribute a balance to this release.
    public var transactions: [TransactionHash]

    static func fromGRPC(_ grpc: Concordium_V2_Release) throws -> Self {
        try .init(
            timestamp: dateFromUnixTimeMillis(grpc.timestamp.value),
            amount: grpc.amount.value,
            transactions: grpc.transactions.map { try .fromGRPC($0) }
        )
    }
}

/// State of the account's release schedule.
/// This is the balance of the account that is owned by the account, but cannot be used until the release point.
public struct ReleaseSchedule: FromGRPC {
    /// Total amount that is locked up in releases.
    public var total: MicroCCDAmount
    /// List of timestamped releases in increasing order of timestamps.
    public var schedule: [Release]

    static func fromGRPC(_ grpc: Concordium_V2_ReleaseSchedule) throws -> Self {
        try .init(total: grpc.total.value, schedule: grpc.schedules.map {
            try .fromGRPC($0)
        })
    }
}

/// Public credential keys currently on the account, together with the threshold
/// needed for a valid signature on a transaction.
public typealias CredentialPublicKeys = ConcordiumWalletCrypto.CredentialPublicKeys

extension CredentialPublicKeys: FromGRPC, Serialize, Deserialize {
    static func fromGRPC(_ grpc: Concordium_V2_CredentialPublicKeys) throws -> Self {
        try .init(
            keys: grpc.keys.reduce(into: [:]) { res, e in
                let idx = try KeyIndex(exactly: e.key) ?! GRPCError.valueOutOfBounds
                res[idx] = try .fromGRPC(e.value)
            },
            threshold: SignatureThreshold(exactly: grpc.threshold.value) ?! GRPCError.valueOutOfBounds
        )
    }

    public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeSerializable(map: keys, lengthPrefix: UInt8.self)
        res += buffer.writeInteger(threshold)
        return res
    }

    public static func deserialize(_ data: inout Cursor) -> CredentialPublicKeys? {
        guard let keys = data.deserialize(mapOf: VerifyKey.self, keys: UInt8.self, lengthPrefix: UInt8.self),
              let threshold = data.parseUInt(UInt8.self) else { return nil }
        return CredentialPublicKeys(keys: keys, threshold: threshold)
    }
}

public typealias VerifyKey = ConcordiumWalletCrypto.VerifyKey

public enum VerifyKeyError: Error, Equatable {
    case unexpectedLength(actual: UInt8)
    case invalidHex
}

extension VerifyKey: FromGRPC, Serialize, Deserialize {
    public static let SIZE: UInt8 = 32
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(0, as: UInt8.self) + buffer.writeData(try! Data(hex: keyHex)) // We unwrap, as initializing safely will mean this always succeeds
    }

    public static func deserialize(_ data: inout Cursor) -> ConcordiumWalletCrypto.VerifyKey? {
        guard let tag = data.parseUInt(UInt8.self) else { return nil }
        switch tag {
        case 0: // schemeId = Ed25519
            guard let key = data.read(num: Self.SIZE).map({ try? Self(ed25519KeyHex: $0.hex) }) else { return nil }
            return key
        default:
            return nil
        }
    }

    /// Safely initialize a verify key from a 32 length byte sequence in hex format
    /// - Throws: ``VerifyKeyError`` in case the passed hex string is not a valid ed25519 verify key
    public init(ed25519KeyHex: String) throws {
        let parsed = try Data(hex: ed25519KeyHex) ?! VerifyKeyError.invalidHex // Check that the data is hex
        guard parsed.count == Self.SIZE else { throw VerifyKeyError.unexpectedLength(actual: UInt8(parsed.count)) }
        self.init(schemeId: "Ed25519", keyHex: ed25519KeyHex)
    }

    static func fromGRPC(_ grpc: Concordium_V2_AccountVerifyKey) throws -> Self {
        switch grpc.key {
        case nil:
            throw GRPCError.missingRequiredValue("verify key")
        case let .ed25519Key(d):
            return try .init(ed25519KeyHex: d.hex) ?! GRPCError.unsupportedValue("Invalid hex string")
        }
    }
}

func yearMonthString(year: UInt32, month: UInt32) -> String {
    String(format: "%04d%02d", year, month)
}

/// A policy is revealed values of attributes that are part of the identity object.
/// Policies are part of credentials.
public typealias Policy = ConcordiumWalletCrypto.Policy

extension Policy: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_Policy) throws -> Self {
        try .init(
            createdAtYearMonth: yearMonthString(year: grpc.createdAt.year, month: grpc.createdAt.month),
            validToYearMonth: yearMonthString(year: grpc.validTo.year, month: grpc.validTo.month),
            revealedAttributes: grpc.attributes.reduce(into: [:]) { res, e in
                let attr = try UInt8(exactly: e.key)
                    .flatMap { AttributeTag(rawValue: $0) }
                    ?! GRPCError.valueOutOfBounds
                res["\(attr)"] = String(data: e.value, encoding: .utf8) // TODO: correct to treat attribute value as UTF-8?
            }
        )
    }
}

public struct CredentialDeploymentValuesInitial: FromGRPC {
    /// Credential keys.
    public var credentialPublicKeys: CredentialPublicKeys
    /// Credential registration ID of the credential.
    public var credentialID: CredentialRegistrationID
    /// Identity of the identity provider who signed the identity object from which this credential is derived.
    public var identityProviderID: IdentityProviderID
    /// Policy of this credential object.
    public var policy: Policy

    static func fromGRPC(_ grpc: Concordium_V2_InitialCredentialValues) throws -> Self {
        try .init(
            credentialPublicKeys: .fromGRPC(grpc.keys),
            credentialID: CredentialRegistrationID.fromGRPC(grpc.credID),
            identityProviderID: grpc.ipID.value,
            policy: .fromGRPC(grpc.policy)
        )
    }
}

public typealias ChainArData = ConcordiumWalletCrypto.ChainArData

extension ChainArData: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_ChainArData) -> Self {
        .init(encIdCredPubShareHex: grpc.encIDCredPubShare.hex)
    }
}

public struct CredentialDeploymentValuesNormal: FromGRPC {
    public var initial: CredentialDeploymentValuesInitial
    /// Anonymity revocation threshold. Must be <= length of ar_data.
    public var revocationThreshold: RevocationThreshold
    /// Anonymity revocation data. List of anonymity revokers which can revoke identity.
    /// NB: The order is important since it is the same order as that signed by the identity provider,
    ///  and permuting the list will invalidate the signature from the identity provider.
    public var anonymityRevokerData: [AnonymityRevokerID: ChainArData]

    static func fromGRPC(_ grpc: Concordium_V2_NormalCredentialValues) throws -> Self {
        try .init(
            initial: CredentialDeploymentValuesInitial(
                credentialPublicKeys: .fromGRPC(grpc.keys),
                credentialID: CredentialRegistrationID.fromGRPC(grpc.credID),
                identityProviderID: grpc.ipID.value,
                policy: .fromGRPC(grpc.policy)
            ),
            revocationThreshold: SignatureThreshold(exactly: grpc.arThreshold.value) ?! GRPCError.valueOutOfBounds,
            anonymityRevokerData: grpc.arData.mapValues { .fromGRPC($0) }
        )
    }

    public func toCryptoType(proofs: Proofs) -> AccountCredential {
        .init(
            arData: anonymityRevokerData,
            credIdHex: initial.credentialID.value.hex,
            credentialPublicKeys: initial.credentialPublicKeys,
            ipIdentity: initial.identityProviderID,
            policy: initial.policy,
            proofs: proofs,
            revocationThreshold: revocationThreshold
        )
    }
}

/// Account credential values without proofs.
public enum AccountCredentialDeploymentValues: FromGRPC {
    case initial(CredentialDeploymentValuesInitial)
    case normal(CredentialDeploymentValuesNormal)

    static func fromGRPC(_ grpc: Concordium_V2_AccountCredential) throws -> Self {
        switch grpc.credentialValues {
        case nil:
            throw GRPCError.missingRequiredValue("credential values")
        case let .initial(v):
            return try .initial(.fromGRPC(v))
        case let .normal(v):
            return try .normal(.fromGRPC(v))
        }
    }
}

/// The state of the encrypted balance of an account.
public struct AccountEncryptedAmount: FromGRPC {
    /// Encrypted amount that is a result of this accounts' actions.
    /// In particular this list includes the aggregate of
    ///
    /// - remaining amounts that result when transferring to public balance
    /// - remaining amounts when transferring to another account
    /// - encrypted amounts that are transferred from public balance
    ///
    /// When a transfer is made all of these must always be used.
    public var selfAmount: EncryptedAmount
    /// Starting index for incoming encrypted amounts.
    /// If an aggregated amount is present then this index is associated with such an amount
    /// and the list of incoming encrypted amounts starts at the index `start_index + 1`.
    public var startIndex: UInt64
    /// If not nil, the amount that has resulted from aggregating other amounts
    /// and the number of aggregated amounts (must be at least 2 if present).
    public var aggregatedAmount: AggregatedAmount?
    /// Amounts starting at `start_index` (or at `start_index + 1` if there is
    /// an aggregated amount present).
    /// They are assumed to be numbered sequentially.
    /// The length of this list is bounded by the maximum number of incoming amounts on the accounts, which is currently 32.
    /// After that aggregation kicks in.
    public var incomingAmounts: [EncryptedAmount]

    static func fromGRPC(_ grpc: Concordium_V2_EncryptedBalance) -> Self {
        .init(
            selfAmount: grpc.selfAmount.value,
            startIndex: grpc.startIndex,
            aggregatedAmount: grpc.aggregatedAmount.value,
            incomingAmounts: grpc.incomingAmounts.map(\.value)
        )
    }
}

/// Information about a baker/validator.
public struct BakerInfo: FromGRPC {
    /// Identity of the baker. This is actually the account index of the account controlling the baker.
    public var bakerID: BakerID
    /// Baker's public key used to check whether they won the lottery or not.
    public var bakerElectionVerifyKey: BakerElectionVerifyKey
    /// Baker's public key used to check that they are indeed the ones who produced the block.
    public var bakerSignatureVerifyKey: BakerSignatureVerifyKey
    /// Baker's public key used to check signatures on finalization records.
    /// This is only used if the baker has sufficient stake to participate in finalization.
    public var bakerAggregationVerifyKey: BakerAggregationVerifyKey

    static func fromGRPC(_ grpc: Concordium_V2_BakerInfo) -> Self {
        .init(
            bakerID: grpc.bakerID.value,
            bakerElectionVerifyKey: grpc.electionKey.value.hex,
            bakerSignatureVerifyKey: grpc.signatureKey.value.hex,
            bakerAggregationVerifyKey: grpc.aggregationKey.value.hex
        )
    }
}

/// Pending change in the baker's stake.
public enum StakePendingChange: FromGRPC {
    /// The stake is being reduced. The new stake will take affect in the given epoch.
    case reduceStake(newStake: MicroCCDAmount, effectiveTime: Date)
    /// The baker will be removed at the end of the given epoch.
    case removeStake(effectiveTime: Date)

    static func fromGRPC(_ grpc: Concordium_V2_StakePendingChange) throws -> Self {
        switch grpc.change {
        case nil:
            throw GRPCError.missingRequiredValue("stake pending change")
        case let .reduce(r):
            return .reduceStake(newStake: r.newStake.value, effectiveTime: dateFromUnixTimeMillis(r.effectiveTime.value))
        case let .remove(r):
            return .removeStake(effectiveTime: dateFromUnixTimeMillis(r.value))
        }
    }
}

/// A fraction of an amount with a precision of 1/100000.
public struct AmountFraction: FromGRPC, Equatable, Serialize, Deserialize {
    public var partsPerHundredThousand: UInt32

    static func fromGRPC(_ grpc: Concordium_V2_AmountFraction) -> Self {
        .init(partsPerHundredThousand: grpc.partsPerHundredThousand)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(partsPerHundredThousand)
    }

    public static func deserialize(_ data: inout Cursor) -> AmountFraction? {
        data.parseUInt(UInt32.self).flatMap { Self(partsPerHundredThousand: $0) }
    }
}

/// Information about how open the pool is to new delegators.
public enum OpenStatus: Int, FromGRPC, Equatable, Serialize, Deserialize {
    /// New delegators may join the pool.
    case openForAll = 0
    /// New delegators may not join, but existing delegators are kept.
    case closedForNew = 1
    /// No delegators are allowed.
    case closedForAll = 2

    static func fromGRPC(_ grpc: Concordium_V2_OpenStatus) throws -> Self {
        try .init(rawValue: grpc.rawValue) ?! GRPCError.unsupportedValue("open status '\(grpc.rawValue)'")
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(rawValue)
    }

    public static func deserialize(_ data: inout Cursor) -> OpenStatus? {
        data.parseUInt(UInt8.self).flatMap { Self(rawValue: Int($0)) }
    }
}

public struct CommissionRates: FromGRPC {
    /// Fraction of finalization rewards charged by the pool owner.
    public var finalization: AmountFraction?
    /// Fraction of baking rewards charged by the pool owner.
    public var baking: AmountFraction?
    /// Fraction of transaction rewards charged by the pool owner.
    public var transaction: AmountFraction?

    static func fromGRPC(_ grpc: Concordium_V2_CommissionRates) -> Self {
        .init(
            finalization: grpc.hasFinalization ? .fromGRPC(grpc.finalization) : nil,
            baking: grpc.hasBaking ? .fromGRPC(grpc.baking) : nil,
            transaction: grpc.hasTransaction ? .fromGRPC(grpc.transaction) : nil
        )
    }
}

/// Additional information about a baking pool.
/// This information is added with the introduction of delegation in protocol version 4.
public struct BakerPoolInfo: FromGRPC {
    /// Whether the pool allows delegators.
    public var openStatus: OpenStatus
    /// The URL that links to the metadata about the pool.
    public var metadataURL: String
    /// The commission rates charged by the pool owner.
    public var commissionRates: CommissionRates

    static func fromGRPC(_ grpc: Concordium_V2_BakerPoolInfo) throws -> Self {
        try .init(
            openStatus: .fromGRPC(grpc.openStatus),
            metadataURL: grpc.url,
            commissionRates: .fromGRPC(grpc.commissionRates)
        )
    }
}

/// Target of delegation.
public enum DelegationTarget: FromGRPC, Equatable, Serialize, Deserialize {
    /// Delegate passively, i.e., to no specific baker.
    case passive
    /// Delegate to a specific baker.
    case baker(BakerID)

    static func fromGRPC(_ grpc: Concordium_V2_DelegationTarget) throws -> Self {
        switch grpc.target {
        case nil:
            throw GRPCError.missingRequiredValue("delegation target")
        case .passive:
            return .passive
        case let .baker(b):
            return .baker(b.value)
        }
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        var res = 0
        switch self {
        case .passive:
            res += buffer.writeInteger(0)
        case let .baker(bakerId):
            res += buffer.writeInteger(1)
            buffer.writeInteger(bakerId)
        }
        return res
    }

    public static func deserialize(_ data: inout Cursor) -> DelegationTarget? {
        guard let tag = data.parseUInt(UInt8.self) else { return nil }
        if tag == 0 { return .passive }

        guard let bakerId = data.parseUInt(BakerID.self) else { return nil }
        return .baker(bakerId)
    }
}

public enum AccountStakingInfo: FromGRPC {
    /// The account is a baker.
    case baker(
        stakedAmount: MicroCCDAmount,
        restakeEarnings: Bool,
        bakerInfo: BakerInfo,
        pendingChange: StakePendingChange?,
        poolInfo: BakerPoolInfo?
    )
    /// The account is delegating stake to a baker.
    case delegated(
        stakedAmount: MicroCCDAmount,
        restakeEarnings: Bool,
        delegationTarget: DelegationTarget,
        pendingChange: StakePendingChange?
    )

    static func fromGRPC(_ grpc: Concordium_V2_AccountStakingInfo) throws -> Self {
        switch grpc.stakingInfo {
        case nil:
            throw GRPCError.missingRequiredValue("account staking info")
        case let .baker(b):
            return try .baker(
                stakedAmount: b.stakedAmount.value,
                restakeEarnings: b.restakeEarnings,
                bakerInfo: .fromGRPC(b.bakerInfo),
                pendingChange: b.hasPendingChange ? .fromGRPC(b.pendingChange) : nil,
                poolInfo: b.hasPoolInfo ? .fromGRPC(b.poolInfo) : nil
            )
        case let .delegator(d):
            return try .delegated(
                stakedAmount: d.stakedAmount.value,
                restakeEarnings: d.restakeEarnings,
                delegationTarget: .fromGRPC(d.target),
                pendingChange: d.hasPendingChange ? .fromGRPC(d.pendingChange) : nil
            )
        }
    }
}

/// Information about the account at a particular point in time on chain.
public struct AccountInfo: FromGRPC {
    /// Next sequence number to be used for transactions signed from this account.
    public var sequenceNumber: SequenceNumber
    /// Current (unencrypted) balance of the account.
    public var amount: MicroCCDAmount
    /// Release schedule for any locked up amount. This could be an empty release schedule.
    public var releaseSchedule: ReleaseSchedule
    /// Map of all currently active credentials on the account.
    /// This includes public keys that can sign for the given credentials,
    /// as well as any revealed attributes.
    /// This map always contains a credential with index 0.
    public var credentials: [CredentialIndex: Versioned<AccountCredentialDeploymentValues>]
    /// Lower bound on how many credentials must sign any given transaction from this account.
    public var threshold: SignatureThreshold
    /// The encrypted balance of the account.
    public var encryptedAmount: AccountEncryptedAmount
    /// The public key for sending encrypted balances to the account.
    public var encryptionKey: ElgamalPublicKey
    /// Internal index of the account.
    /// Accounts on the chain get sequential indices.
    /// These should generally not be used outside of the chain.
    /// The account address is meant to be used to refer to accounts,
    /// however the account index serves the role of the baker ID if the account is a baker.
    /// Hence it is exposed here as well.
    public var index: AccountIndex
    /// Present if the account is a baker or delegator.
    /// In that case it is the information about the baker or delegator.
    public var stake: AccountStakingInfo?
    /// Canonical address of the account.
    /// This is derived from the first credential that created the account.
    public var address: AccountAddress

    static func fromGRPC(_ grpc: Concordium_V2_AccountInfo) throws -> Self {
        try .init(
            sequenceNumber: grpc.sequenceNumber.value,
            amount: grpc.amount.value,
            releaseSchedule: .fromGRPC(grpc.schedule),
            credentials: grpc.creds.mapValues {
                try Versioned(
                    version: 0, // mirroring Rust SDK
                    value: .fromGRPC($0)
                )
            },
            threshold: SignatureThreshold(exactly: grpc.threshold.value) ?! GRPCError.valueOutOfBounds,
            encryptedAmount: .fromGRPC(grpc.encryptedBalance),
            encryptionKey: grpc.encryptionKey.value.hex,
            index: grpc.index.value,
            stake: grpc.hasStake ? .fromGRPC(grpc.stake) : nil,
            address: AccountAddress(grpc.address.value)
        )
    }
}
