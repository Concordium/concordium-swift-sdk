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
    static func fromGrpcType(_ grpc: Concordium_V2_IpInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGrpcType(grpc.description_p),
            verifyKey: grpc.verifyKey.value.hex,
            cdiVerifyKey: grpc.cdiVerifyKey.value.hex
        )
    }
}

extension AnonymityRevokerInfo {
    static func fromGrpcType(_ grpc: Concordium_V2_ArInfo) -> Self {
        .init(
            identity: grpc.identity.value,
            description: .fromGrpcType(grpc.description_p),
            publicKey: grpc.publicKey.value.hex
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
            signature: container.decode(String.self, forKey: .signature)
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
            idCredPub: container.decode(String.self, forKey: .idCredPub),
            ipArData: container.decode([String: ArData].self, forKey: .ipArData).reduce(into: [:]) { res, e in
                guard let key = UInt32(e.key) else {
                    throw DecodingError.dataCorruptedError(forKey: .ipArData, in: container, debugDescription: "invalid key index")
                }
                res[key] = e.value
            },
            choiceArData: container.decode(ChoiceArParameters.self, forKey: .choiceArData),
            idCredSecCommitment: container.decode(String.self, forKey: .idCredSecCommitment),
            prfKeyCommitmentWithIp: container.decode(String.self, forKey: .prfKeyCommitmentWithIP),
            prfKeySharingCoeffCommitments: container.decode([String].self, forKey: .prfKeySharingCoeffCommitments),
            proofsOfKnowledge: container.decode(String.self, forKey: .proofsOfKnowledge)
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
            encPrfKeyShare: container.decode(String.self, forKey: .encPrfKeyShare),
            proofComEncEq: container.decode(String.self, forKey: .proofComEncEq)
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
            validTo: container.decode(String.self, forKey: .validTo),
            createdAt: container.decode(String.self, forKey: .createdAt),
            maxAccounts: container.decode(UInt8.self, forKey: .maxAccounts),
            chosenAttributes: container.decode([String: String].self, forKey: .chosenAttributes)
        )
    }
}

extension Description {
    static func fromGrpcType(_ grpc: Concordium_V2_Description) -> Self {
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

public struct IdentityIssuanceResponseJson: Decodable {
    public var status: String
    public var token: Token

    public init(status: String, token: Token) {
        self.status = status
        self.token = token
    }

    public struct Token: Decodable {
        public var identityObject: Versioned<IdentityObject>

        public init(identityObject: Versioned<IdentityObject>) {
            self.identityObject = identityObject
        }
    }
}

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

    // Make it explicit that the case names are significant.
    public var description: String { "\(self)" }
}
