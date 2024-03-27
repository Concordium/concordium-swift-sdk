import ConcordiumWalletCrypto
import Foundation

public struct IdentityProvider {
    public var info: IdentityProviderInfo
    public var metadata: Metadata
    public var anonymityRevokers: [UInt32: AnonymityRevokerInfo]

    public init(info: IdentityProviderInfo, metadata: Metadata, anonymityRevokers: [UInt32: AnonymityRevokerInfo]) {
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
public typealias ArData = ConcordiumWalletCrypto.ArData
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
            ipArData: container.decode([String: ArData].self, forKey: .ipArData).reduce(into: [:]) { res, e in
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

extension ArData: Decodable {
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
            arIdentities: container.decode([UInt32].self, forKey: .arIdentities),
            threshold: container.decode(UInt32.self, forKey: .threshold)
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
        let detail = try container.decodeIfPresent(String.self, forKey: .detail)
        switch status {
        case "done":
            let token = try container.decode(TokenJson.self, forKey: .token)
            result = .success(identity: token.identityObject, detail: detail)
        case "error":
            result = .failure(detail: detail)
        case "pending":
            result = .pending(detail: detail)
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "unexpected status '\(status)'")
        }
    }

    struct TokenJson: Decodable {
        public var identityObject: Versioned<IdentityObject>

        public init(identityObject: Versioned<IdentityObject>) {
            self.identityObject = identityObject
        }
    }
}

// public struct IdentityIssuedResponseJson: Decodable {
//    public var status: String
//    public var token: Token?
//    public var details: String?
//
//    public init(status: String, token: Token) {
//        self.status = status
//        self.token = token
//    }
//
//    public struct Token: Decodable {
//        public var identityObject: Versioned<IdentityObject>
//
//        public init(identityObject: Versioned<IdentityObject>) {
//            self.identityObject = identityObject
//        }
//    }
// }

public enum AttributeType: UInt8, CustomStringConvertible, CaseIterable {
    case firstName = 0
    case lastName = 1
    case sex = 2
    case dob = 3
    case countryOfResidence = 4
    case nationality = 5
    case idDocType = 6
    case idDocNo = 7
    case idDocIssuer = 8
    case idDocIssuedAt = 9
    case idDocExpiresAt = 10
    case nationalIdNo = 11
    case taxIdNo = 12
    case lei = 13

    public var description: String {
        switch self {
        case .firstName: return "firstName"
        case .lastName: return "lastName"
        case .sex: return "sex"
        case .dob: return "dob"
        case .countryOfResidence: return "countryOfResidence"
        case .nationality: return "nationality"
        case .idDocType: return "idDocType"
        case .idDocNo: return "idDocNo"
        case .idDocIssuer: return "idDocIssuer"
        case .idDocIssuedAt: return "idDocIssuedAt"
        case .idDocExpiresAt: return "idDocExpiresAt"
        case .nationalIdNo: return "nationalIdNo"
        case .taxIdNo: return "taxIdNo"
        case .lei: return "lei"
        }
    }
}

public typealias AccountCredential = ConcordiumWalletCrypto.AccountCredential
