import ConcordiumWalletCrypto
import Foundation

public enum WalletIdentityError: Error {
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
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
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
        icon = try container.decode(String.self, forKey: .icon)
        support = try container.decodeIfPresent(String.self, forKey: .support)
        issuanceStart = try container.decode(URL.self, forKey: .issuanceStart)
        recoveryStart = try container.decode(URL.self, forKey: .recoveryStart)
    }
}

public struct IdentityProvider {
    public var identity: UInt32
    public var description: Description
    public var verifyKey: String
    public var cdiVerifyKey: String
    public var metadata: Metadata

    func toCryptoType() -> IdentityProviderInfo {
        IdentityProviderInfo(
            identity: identity,
            description: description.toCryptoType(),
            verifyKey: verifyKey,
            cdiVerifyKey: cdiVerifyKey
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
            ipArData: container.decode([String: ArData].self, forKey: .ipArData).reduce(into: [:]) { acc, e in
                guard let key = UInt32(e.key) else {
                    throw DecodingError.dataCorruptedError(forKey: .ipArData, in: container, debugDescription: "invalid key index")
                }
                return acc[key] = e.value
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

public class WalletIdentity {
    private let generator: WalletIdentityRequestGenerator

    public init(generator: WalletIdentityRequestGenerator) {
        self.generator = generator
    }

    public func recoverIdentity(provider: IdentityProvider, index: UInt32, global: CryptographicParameters) async throws -> Versioned<IdentityObject> {
        // FUTURE: Use 'Date.now' instead of 'Date()' once platform restrictions allow it.
        let requestJson = try generator.createRecoveryRequestJson(provider: provider, index: index, context: global, time: Date())
        let url = try recoveryUrl(baseUrl: provider.metadata.recoveryStart, requestJson: requestJson) ?! WalletIdentityError.cannotConstructRecoveryUrl
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Versioned<IdentityObject>.self, from: data)
    }

    private func recoveryUrl(baseUrl: URL, requestJson: String) -> URL? {
        // FUTURE: The URL method 'appendComponent(queryItems:)' is nicer but requires bumping supported platforms.
        var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "state", value: requestJson)]
        return components?.url
    }
}

public class WalletIdentityRequestGenerator {
    private let seed: WalletSeed

    public init(seed: WalletSeed) {
        self.seed = seed
    }

    public func createRecoveryRequestJson(provider: IdentityProvider, index: UInt32, context: CryptographicParameters, time: Date) throws -> String {
        try createIdentityRecoveryRequestJson(
            input: IdentityRecoveryRequestInput(
                ipInfo: provider.toCryptoType(),
                globalContext: context.toCryptoType(),
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSec: seed.credSec(
                    of: IdentityCoordinates(
                        providerIndex: provider.identity,
                        index: index
                    )
                )
            )
        )
    }
}
