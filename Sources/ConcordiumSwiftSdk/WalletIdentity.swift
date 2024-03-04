import ConcordiumWalletCrypto
import Foundation

public enum WalletIdentityError: Error {
    case cannotConstructIssuanceUrl
    case cannotConstructRecoveryUrl
    case invalidUtf8
}

public struct Description: Decodable {
    public var name: String?
    public var description: String?
    public var url: String?

    public init(name: String? = "", description: String? = "", url: String? = "") {
        self.name = name
        self.description = description
        self.url = url
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
    public var metadata: Metadata
    public var arsInfos: [UInt32: AnonymityRevoker]

    func toCryptoType() -> IdentityProviderInfo {
        IdentityProviderInfo(
            identity: identity,
            description: description.toCryptoType(),
            verifyKey: verifyKey,
            cdiVerifyKey: cdiVerifyKey
        )
    }
}

public struct AnonymityRevoker {
    public var identity: UInt32
    public var description: Description
    public var publicKey: String

    func toCryptoType() -> AnonymityRevokerInfo {
        AnonymityRevokerInfo(
            identity: identity,
            description: description.toCryptoType(),
            publicKey: publicKey
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

public typealias IdentityIssuanceRequest = HttpRequest<Versioned<IdentityObject>>
public typealias IdentityRecoveryRequest = HttpRequest<Versioned<IdentityObject>> // TODO: ?

public class WalletIdentityRequestUrlGenerator {
    private let callbackUrl: URL // In Android example wallet: concordiumwallet-example://identity-issuer/callback

    public init(callbackUrl: URL) {
        self.callbackUrl = callbackUrl
    }

    public func issuanceRequest(baseUrl: URL, requestJson: String) throws -> IdentityIssuanceRequest {
        let url = try issuanceRequestUrl(baseUrl: baseUrl, requestJson: requestJson) ?! WalletIdentityError.cannotConstructIssuanceUrl
        return HttpRequest(url: url)
    }

    private func issuanceRequestUrl(baseUrl: URL, requestJson: String) -> URL? {
        // FUTURE: The URL method 'appending(queryItems:)' is nicer but requires bumping supported platforms.
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "\(callbackUrl).CALLBACK_URL"),
            URLQueryItem(name: "scope", value: "identity"),
            URLQueryItem(name: "state", value: requestJson),
        ]
        return components.url
    }

    public func recoveryRequest(baseUrl: URL, requestJson: String) throws -> IdentityRecoveryRequest {
        let url = try recoveryRequestUrl(baseUrl: baseUrl, requestJson: requestJson) ?! WalletIdentityError.cannotConstructRecoveryUrl
        return HttpRequest(url: url)
    }

    private func recoveryRequestUrl(baseUrl: URL, requestJson: String) -> URL? {
        // FUTURE: The URL method 'appending(queryItems:)' is nicer but requires bumping supported platforms.
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "state", value: requestJson),
        ]
        return components.url
    }
}
