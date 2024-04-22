import ConcordiumWalletCrypto
import Foundation

public struct IdentityProvider {
    public var info: IdentityProviderInfo
    public var metadata: Metadata
    public var anonymityRevokers: [AnonymityRevokerID: AnonymityRevokerInfo]

    public init(info: IdentityProviderInfo, metadata: Metadata, anonymityRevokers: [AnonymityRevokerID: AnonymityRevokerInfo]) {
        self.info = info
        self.metadata = metadata
        self.anonymityRevokers = anonymityRevokers
    }
}

public typealias IdentityProviderInfo = ConcordiumWalletCrypto.IdentityProviderInfo
public typealias AnonymityRevokerInfo = ConcordiumWalletCrypto.AnonymityRevokerInfo
public typealias Description = ConcordiumWalletCrypto.Description
public typealias IdentityObject = ConcordiumWalletCrypto.IdentityObject
public typealias AttributeList = ConcordiumWalletCrypto.AttributeList
public typealias ChoiceArParameters = ConcordiumWalletCrypto.ChoiceArParameters
public typealias AnonymityRevokerData = ConcordiumWalletCrypto.ArData
public typealias PreIdentityObject = ConcordiumWalletCrypto.PreIdentityObject

extension IdentityProviderInfo {
    static func fromGRPCType(_ grpc: Concordium_V2_IpInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGRPCType(grpc.description_p),
            verifyKeyHex: grpc.verifyKey.value.hex,
            cdiVerifyKeyHex: grpc.cdiVerifyKey.value.hex
        )
    }
}

extension AnonymityRevokerInfo {
    static func fromGRPCType(_ grpc: Concordium_V2_ArInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGRPCType(grpc.description_p),
            publicKeyHex: grpc.publicKey.value.hex
        )
    }
}

extension IdentityObject: Decodable {
    enum CodingKeys: CodingKey {
        case preIdentityObject
        case attributeList
        case signature
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            preIdentityObject: container.decode(PreIdentityObject.self, forKey: .preIdentityObject),
            attributeList: container.decode(AttributeList.self, forKey: .attributeList),
            signatureHex: container.decode(String.self, forKey: .signature)
        )
    }
}

extension PreIdentityObject: Decodable {
    enum CodingKeys: CodingKey {
        case idCredPub
        case ipArData
        case choiceArData
        case idCredSecCommitment
        case prfKeyCommitmentWithIP
        case prfKeySharingCoeffCommitments
        case proofsOfKnowledge
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            idCredPubHex: container.decode(String.self, forKey: .idCredPub),
            ipArData: container.decode([String: AnonymityRevokerData].self, forKey: .ipArData).reduce(into: [:]) { res, e in
                guard let key = UInt32(e.key) else {
                    throw DecodingError.dataCorruptedError(forKey: .ipArData, in: container, debugDescription: "invalid key index")
                }
                res[key] = e.value
            },
            choiceArData: container.decode(ChoiceArParameters.self, forKey: .choiceArData),
            idCredSecCommitmentHex: container.decode(String.self, forKey: .idCredSecCommitment),
            prfKeyCommitmentWithIpHex: container.decode(String.self, forKey: .prfKeyCommitmentWithIP),
            prfKeySharingCoeffCommitmentsHex: container.decode([String].self, forKey: .prfKeySharingCoeffCommitments),
            proofsOfKnowledgeHex: container.decode(String.self, forKey: .proofsOfKnowledge)
        )
    }
}

extension AnonymityRevokerData: Decodable {
    enum CodingKeys: CodingKey {
        case encPrfKeyShare
        case proofComEncEq
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            encPrfKeyShareHex: container.decode(String.self, forKey: .encPrfKeyShare),
            proofComEncEqHex: container.decode(String.self, forKey: .proofComEncEq)
        )
    }
}

extension ChoiceArParameters: Decodable {
    enum CodingKeys: CodingKey {
        case arIdentities
        case threshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            arIdentities: container.decode([AnonymityRevokerID].self, forKey: .arIdentities),
            threshold: UInt32(container.decode(RevocationThreshold.self, forKey: .threshold)) // TODO: remove conversion
        )
    }
}

extension AttributeList: Decodable {
    enum CodingKeys: CodingKey {
        case validTo
        case createdAt
        case maxAccounts
        case chosenAttributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            validToYearMonth: container.decode(String.self, forKey: .validTo),
            createdAtYearMonth: container.decode(String.self, forKey: .createdAt),
            maxAccounts: container.decode(UInt8.self, forKey: .maxAccounts),
            chosenAttributes: container.decode([String: String].self, forKey: .chosenAttributes)
        )
    }
}

extension Description {
    static func fromGRPCType(_ grpc: Concordium_V2_Description) -> Self {
        .init(name: grpc.name, url: grpc.url, description: grpc.description_p)
    }
}

extension Description: Decodable {
    /// Fields used in Wallet Proxy response.
    enum CodingKeys: CodingKey {
        case name
        case description
        case url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decodeIfPresent(String.self, forKey: .name) ?? "",
            url: container.decodeIfPresent(String.self, forKey: .url) ?? "",
            description: container.decodeIfPresent(String.self, forKey: .description) ?? ""
        )
    }
}

public struct Metadata: Decodable {
    public var icon: String
    public var support: String?
    public var issuanceStart: URL
    public var recoveryStart: URL

    public init(icon: String, support: String?, issuanceStart: URL, recoveryStart: URL) {
        self.icon = icon
        self.support = support
        self.issuanceStart = issuanceStart
        self.recoveryStart = recoveryStart
    }

    /// Fields used in Wallet Proxy response.
    enum CodingKeys: CodingKey {
        case icon
        case support
        case issuanceStart
        case recoveryStart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            icon: container.decode(String.self, forKey: .icon),
            support: container.decodeIfPresent(String.self, forKey: .support),
            issuanceStart: container.decode(URL.self, forKey: .issuanceStart),
            recoveryStart: container.decode(URL.self, forKey: .recoveryStart)
        )
    }
}

// TODO: Should name 'IdentityVerificationStatus'?
public enum IdentityIssuanceResult {
    case pending(detail: String?)
    case failure(detail: String?)
    case success(identity: Versioned<IdentityObject>, detail: String?)
}

public struct IdentityIssuanceResponse: Decodable {
    public var result: IdentityIssuanceResult

    enum CodingKeys: CodingKey {
        case status
        case token
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        result = try Self.decodeFromStatus(status, container: container)
    }

    private static func decodeFromStatus(_ status: String, container: KeyedDecodingContainer<CodingKeys>) throws -> IdentityIssuanceResult {
        let detail = try container.decodeIfPresent(String.self, forKey: .detail)
        switch status {
        case "done":
            let token = try container.decode(TokenJSON.self, forKey: .token)
            return .success(identity: token.identityObject, detail: detail)
        case "error":
            return .failure(detail: detail)
        case "pending":
            return .pending(detail: detail)
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "unexpected status '\(status)'")
        }
    }

    struct TokenJSON: Decodable {
        public var identityObject: Versioned<IdentityObject>
    }
}

/// The supported set of attributes which are stored on identities and optionally revealed by accounts.
/// In some contexts (such as the gRPC API), attribute tags are represented by a byte (the raw type of this enum).
/// Where human readability is a concern, the string representation implemented by ``description`` is used.
/// Note that since ``AttributeList`` (which is a component of ``IdentityObject``) is defined in another library, it cannot use this type.
/// Instead, its field `chosenAttributes` is a map from the string representation of the tag to the value.
/// Use the appropriate initializer of this type to convert it.
/// All attribute values are strings of 31 bytes or less. The expected format of the values is documented
/// [here](https://docs.google.com/spreadsheets/d/1CxpFvtAoUcylHQyeBtRBaRt1zsibtpmQOVsk7bsHPGA/edit).
public enum AttributeTag: UInt8, CustomStringConvertible, CaseIterable {
    /// First name (format: string up to 31 bytes).
    case firstName = 0
    /// Last name (format: string up to 31 bytes).
    case lastName = 1
    /// Sex (format: ISO/IEC 5218).
    case sex = 2
    /// Date of birth (format: ISO8601 YYYYMMDD).
    case dateOfBirth = 3
    /// Country of residence (format: ISO3166-1 alpha-2).
    case countryOfResidence = 4
    /// Country of nationality (format: ISO3166-1 alpha-2).
    case nationality = 5
    /// Identity document type
    ///
    /// Format:
    /// - 0 : na
    /// - 1 : passport
    /// - 2 : national ID card
    /// - 3 : driving license
    /// - 4 : immigration card
    /// - eID string (see below)
    ///
    /// eID strings as of Apr 2024:
    /// - DK:MITID        : Danish MitId
    /// - SE:BANKID       : Swedish BankID
    /// - NO:BANKID       : Norwegian BankID
    /// - NO:VIPPS        : Norwegian Vipps
    /// - FI:TRUSTNETWORK : Finnish Trust Network
    /// - NL:DIGID        : Netherlands DigiD
    /// - NL:IDIN         : Netherlands iDIN
    /// - BE:EID          : Belgian eID
    /// - ITSME           : (Cross-national) ItsME
    /// - SOFORT          : (Cross-national) Sofort
    case idDocType = 6
    /// Identity document number (format: string up to 31 bytes).
    case idDocNo = 7
    /// Identity document issuer (format: ISO3166-1 alpha-2 or ISO3166-2 if applicable).
    case idDocIssuer = 8
    /// Time from which the ID is valid (format: ISO8601 YYYYMMDD).
    case idDocIssuedAt = 9
    /// Time to which the ID is valid (format: ISO8601 YYYYMMDD).
    case idDocExpiresAt = 10
    /// National ID number (format: string up to 31 bytes).
    case nationalIdNo = 11
    /// Tax ID number (format: string up to 31 bytes).
    case taxIdNo = 12
    /// LEI-code - companies only (format: ISO17442).
    case legalEntityId = 13

    public init?(_ description: String) {
        switch description {
        case "firstName": self = .firstName
        case "lastName": self = .lastName
        case "sex": self = .sex
        case "dob": self = .dateOfBirth
        case "countryOfResidence": self = .countryOfResidence
        case "nationality": self = .nationality
        case "idDocType": self = .idDocType
        case "idDocNo": self = .idDocNo
        case "idDocIssuer": self = .idDocIssuer
        case "idDocIssuedAt": self = .idDocIssuedAt
        case "idDocExpiresAt": self = .idDocExpiresAt
        case "nationalIdNo": self = .nationalIdNo
        case "taxIdNo": self = .taxIdNo
        case "lei": self = .legalEntityId
        default: return nil
        }
    }

    public var description: String {
        switch self {
        case .firstName: return "firstName"
        case .lastName: return "lastName"
        case .sex: return "sex"
        case .dateOfBirth: return "dob"
        case .countryOfResidence: return "countryOfResidence"
        case .nationality: return "nationality"
        case .idDocType: return "idDocType"
        case .idDocNo: return "idDocNo"
        case .idDocIssuer: return "idDocIssuer"
        case .idDocIssuedAt: return "idDocIssuedAt"
        case .idDocExpiresAt: return "idDocExpiresAt"
        case .nationalIdNo: return "nationalIdNo"
        case .taxIdNo: return "taxIdNo"
        case .legalEntityId: return "lei"
        }
    }
}

public typealias AccountCredential = ConcordiumWalletCrypto.AccountCredential
