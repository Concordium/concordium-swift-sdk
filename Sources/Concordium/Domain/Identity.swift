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

extension IdentityProviderInfo: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_IpInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGRPC(grpc.description_p),
            verifyKey: grpc.verifyKey.value,
            cdiVerifyKey: grpc.cdiVerifyKey.value
        )
    }
}

extension AnonymityRevokerInfo: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_ArInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGRPC(grpc.description_p),
            publicKey: grpc.publicKey.value
        )
    }
}

extension ConcordiumWalletCrypto.IdentityObject: Swift.Decodable {
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
            signature: Data(hex: container.decode(String.self, forKey: .signature))
        )
    }
}

extension ConcordiumWalletCrypto.PreIdentityObject: Swift.Decodable {
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
            idCredPub: Data(hex: container.decode(String.self, forKey: .idCredPub)),
            ipArData: container.decode([String: AnonymityRevokerData].self, forKey: .ipArData).reduce(into: [:]) { res, e in
                guard let key = UInt32(e.key) else {
                    throw DecodingError.dataCorruptedError(forKey: .ipArData, in: container, debugDescription: "invalid key index")
                }
                res[key] = e.value
            },
            choiceArData: container.decode(ChoiceArParameters.self, forKey: .choiceArData),
            idCredSecCommitment: Data(hex: container.decode(String.self, forKey: .idCredSecCommitment)),
            prfKeyCommitmentWithIp: Data(hex: container.decode(String.self, forKey: .prfKeyCommitmentWithIP)),
            prfKeySharingCoeffCommitments: container.decode([String].self, forKey: .prfKeySharingCoeffCommitments).map { try Data(hex: $0) },
            proofsOfKnowledge: Data(hex: container.decode(String.self, forKey: .proofsOfKnowledge))
        )
    }
}

extension ConcordiumWalletCrypto.ArData: Swift.Decodable {
    enum CodingKeys: CodingKey {
        case encPrfKeyShare
        case proofComEncEq
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            encPrfKeyShare: Data(hex: container.decode(String.self, forKey: .encPrfKeyShare)),
            proofComEncEq: Data(hex: container.decode(String.self, forKey: .proofComEncEq))
        )
    }
}

extension ConcordiumWalletCrypto.ChoiceArParameters: Swift.Decodable {
    enum CodingKeys: CodingKey {
        case arIdentities
        case threshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            arIdentities: container.decode([AnonymityRevokerID].self, forKey: .arIdentities),
            threshold: container.decode(RevocationThreshold.self, forKey: .threshold)
        )
    }
}

extension ConcordiumWalletCrypto.AttributeList: Swift.Decodable {
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
            chosenAttributes: container.decode([AttributeTag: String].self, forKey: .chosenAttributes)
        )
    }
}

extension Description: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_Description) -> Self {
        .init(name: grpc.name, url: grpc.url, description: grpc.description_p)
    }
}

extension ConcordiumWalletCrypto.Description: Swift.Decodable {
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

public typealias IdentityVerificationResult = Result<Versioned<IdentityObject>, IdentityVerificationError>
public typealias IdentityVerificationStatusRequest = HTTPRequest<IdentityVerificationStatusResponse>

public enum IdentityVerificationError: Error {
    /// Identity verification failed with the attached string containing any reason provided by the identity provider.
    case failure(String?)
}

public enum IdentityVerificationStatus {
    case pending
    case error
    case done(Versioned<IdentityObject>)
}

public struct IdentityVerificationStatusResponse: Decodable {
    public var status: IdentityVerificationStatus
    public var detail: String?

    enum CodingKeys: CodingKey {
        case status
        case token
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let s = try container.decode(String.self, forKey: .status)
        status = try Self.decodeStatus(s, container: container)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
    }

    private static func decodeStatus(_ status: String, container: KeyedDecodingContainer<CodingKeys>) throws -> IdentityVerificationStatus {
        switch status {
        case "pending":
            return .pending
        case "error":
            return .error
        case "done":
            let token = try container.decode(TokenJSON.self, forKey: .token)
            return .done(token.identityObject)
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "unexpected status '\(status)'")
        }
    }

    struct TokenJSON: Decodable {
        public var identityObject: Versioned<IdentityObject>
    }

    public var result: IdentityVerificationResult? {
        switch status {
        case .pending:
            return nil
        case .error:
            return .failure(.failure(detail))
        case let .done(identity):
            return .success(identity)
        }
    }
}

public typealias IdentityRecoveryRequest = HTTPRequest<IdentityRecoveryResponse>

public struct IdentityRecoveryResponse: Decodable {
    public var result: Result<Versioned<IdentityObject>, IdentityRecoveryError>

    public init(from decoder: any Decoder) throws {
        do {
            result = try .failure(.init(from: decoder))
        } catch {
            result = try .success(.init(from: decoder))
        }
    }
}

public struct IdentityRecoveryError: Decodable, Error {
    public var code: Int
    public var message: String
}

/// The supported set of attributes which are stored on identities and optionally revealed by accounts.
/// In some contexts (such as the gRPC API), attribute tags are represented by a byte (the raw type of this enum).
/// Where human readability is a concern, the string representation implemented by ``description`` is used.
/// Note that since ``AttributeList`` (which is a component of ``IdentityObject``) is defined in another library, it cannot use this type.
/// Instead, its field `chosenAttributes` is a map from the string representation of the tag to the value.
/// Use the appropriate initializer of this type to convert it.
/// All attribute values are strings of 31 bytes or less. The expected format of the values is documented
/// [here](https://docs.google.com/spreadsheets/d/1CxpFvtAoUcylHQyeBtRBaRt1zsibtpmQOVsk7bsHPGA/edit).
public typealias AttributeTag = ConcordiumWalletCrypto.AttributeTag

extension ConcordiumWalletCrypto.AttributeTag: Swift.CustomStringConvertible, Swift.CaseIterable, Swift.CodingKeyRepresentable {
    public enum CodingKeys: CodingKey {
        case firstName
        case lastName
        case sex
        case dob
        case countryOfResidence
        case nationality
        case idDocType
        case idDocNo
        case idDocIssuer
        case idDocIssuedAt
        case idDocExpiresAt
        case nationalIdNo
        case taxIdNo
        case lei
        case legalName
        case legalCountry
        case businessNumber
        case registrationAuth
    }

    public var codingKey: any CodingKey {
        CodingKeys(stringValue: description)!
    }

    public init?<T>(codingKey: T) where T: CodingKey {
        guard let value = Self(codingKey.stringValue) else { return nil }
        self = value
    }

    public static var allCases: [AttributeTag] = [.firstName, .lastName, .sex, .dateOfBirth, .countryOfResidence, .nationality, .idDocType, .idDocNo, .idDocIssuer, .idDocIssuedAt, .idDocExpiresAt, .nationalIdNo, .taxIdNo, .legalEntityId, .legalName, .legalCountry, .businessNumber, .registrationAuth]

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
        case "legalName": self = .legalName
        case "legalCountry": self = .legalCountry
        case "businessNumber": self = .businessNumber
        case "registrationAuth": self = .registrationAuth
        default: return nil
        }
    }

    init?(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .firstName
        case 1: self = .lastName
        case 2: self = .sex
        case 3: self = .dateOfBirth
        case 4: self = .countryOfResidence
        case 5: self = .nationality
        case 6: self = .idDocType
        case 7: self = .idDocNo
        case 8: self = .idDocIssuer
        case 9: self = .idDocIssuedAt
        case 10: self = .idDocExpiresAt
        case 11: self = .nationalIdNo
        case 12: self = .taxIdNo
        case 13: self = .legalEntityId
        case 14: self = .legalName
        case 15: self = .legalCountry
        case 16: self = .businessNumber
        case 17: self = .registrationAuth
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
        case .legalName: return "legalName"
        case .legalCountry: return "legalCountry"
        case .businessNumber: return "businessNumber"
        case .registrationAuth: return "registrationAuth"
        }
    }

    public var rawValue: UInt8 {
        switch self {
        case .firstName: return 0
        case .lastName: return 1
        case .sex: return 2
        case .dateOfBirth: return 3
        case .countryOfResidence: return 4
        case .nationality: return 5
        case .idDocType: return 6
        case .idDocNo: return 7
        case .idDocIssuer: return 8
        case .idDocIssuedAt: return 9
        case .idDocExpiresAt: return 10
        case .nationalIdNo: return 11
        case .taxIdNo: return 12
        case .legalEntityId: return 13
        case .legalName: return 14
        case .legalCountry: return 15
        case .businessNumber: return 16
        case .registrationAuth: return 17
        }
    }
}

extension AttributeTag: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try .init(value) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected value \(value) when decoding 'AttributeTag'")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public typealias AccountCredential = ConcordiumWalletCrypto.AccountCredential
