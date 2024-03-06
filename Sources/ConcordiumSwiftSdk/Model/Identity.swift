import ConcordiumWalletCrypto
import Foundation

public struct Description: Decodable {
    public var name: String?
    public var description: String?
    public var url: String?

    public init(name: String?, description: String?, url: String?) {
        self.name = name
        self.description = description
        self.url = url
    }

    static func fromGrpcType(_ grpc: Concordium_V2_Description) -> Description {
        .init(name: grpc.name, description: grpc.description_p, url: grpc.url)
    }

    /// Fields used in Wallet Proxy response.
    enum CodingKeys: CodingKey {
        case name
        case description
        case url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decodeIfPresent(String.self, forKey: .name),
            description: container.decodeIfPresent(String.self, forKey: .description),
            url: container.decodeIfPresent(String.self, forKey: .url)
        )
    }

    func toCryptoType() -> ConcordiumWalletCrypto.Description {
        ConcordiumWalletCrypto.Description(
            name: name ?? "",
            url: url ?? "",
            description: description ?? ""
        )
    }
}

public struct Metadata: Decodable {
    public var icon: String
    public var support: String?
    public var issuanceStart: URL
    public var recoveryStart: URL

    public init(icon: String, support: String? = "", issuanceStart: URL, recoveryStart: URL) {
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

public struct IdentityProvider {
    public var identity: UInt32
    public var description: Description
    public var verifyKey: String
    public var cdiVerifyKey: String

    public init(identity: UInt32, description: Description, verifyKey: String, cdiVerifyKey: String) {
        self.identity = identity
        self.description = description
        self.verifyKey = verifyKey
        self.cdiVerifyKey = cdiVerifyKey
    }

    static func fromGrpcType(grpc: Concordium_V2_IpInfo) -> IdentityProvider {
        IdentityProvider(
            identity: grpc.identity.value,
            description: .fromGrpcType(grpc.description_p),
            verifyKey: grpc.verifyKey.value.hex,
            cdiVerifyKey: grpc.cdiVerifyKey.value.hex
        )
    }

    func toCryptoType() -> IdentityProviderInfo {
        IdentityProviderInfo(
            identity: identity,
            description: description.toCryptoType(),
            verifyKey: verifyKey,
            cdiVerifyKey: cdiVerifyKey
        )
    }
}

// TODO: Very unsure whether this is the right solution...
public struct IdentityProviderExt {
    public var info: IdentityProvider
    public var metadata: Metadata
    public var arsInfos: [UInt32: AnonymityRevoker]

    public init(info: IdentityProvider, metadata: Metadata, arsInfos: [UInt32: AnonymityRevoker]) {
        self.info = info
        self.metadata = metadata
        self.arsInfos = arsInfos
    }
}

public struct AnonymityRevoker {
    public var identity: UInt32
    public var description: Description
    public var publicKey: String

    public init(identity: UInt32, description: Description, publicKey: String) {
        self.identity = identity
        self.description = description
        self.publicKey = publicKey
    }

    static func fromGrpcType(_ grpc: Concordium_V2_ArInfo) -> AnonymityRevoker {
        AnonymityRevoker(
            identity: grpc.identity.value,
            description: .fromGrpcType(grpc.description_p),
            publicKey: grpc.publicKey.value.hex
        )
    }

    func toCryptoType() -> AnonymityRevokerInfo {
        AnonymityRevokerInfo(
            identity: identity,
            description: description.toCryptoType(),
            publicKey: publicKey
        )
    }
}

public typealias IdentityObject = ConcordiumWalletCrypto.IdentityObject
public typealias AttributeList = ConcordiumWalletCrypto.AttributeList
public typealias ChoiceArParameters = ConcordiumWalletCrypto.ChoiceArParameters
public typealias ArData = ConcordiumWalletCrypto.ArData
public typealias PreIdentityObject = ConcordiumWalletCrypto.PreIdentityObject

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

    public var description: String { "\(self)" }
}
