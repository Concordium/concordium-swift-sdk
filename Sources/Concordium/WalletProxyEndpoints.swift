import Foundation

public enum WalletProxyEndpointError: Error {
    case cannotConstructURL
}

public class WalletProxyEndpoints {
    let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public var getIdentityProviders: HTTPRequest<[IdentityProviderJSON]> {
        get throws {
            try HTTPRequest(url: URL(string: "/v1/ip_info", relativeTo: baseURL) ?! WalletProxyEndpointError.cannotConstructURL)
        }
    }
}

public struct IdentityProviderJSON: Decodable {
    public var ipInfo: IdentityProviderInfo
    public var arsInfos: [AnonymityRevokerID: AnonymityRevokerInfo]
    public var metadata: Metadata

    enum CodingKeys: CodingKey {
        case ipInfo
        case arsInfos
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ipInfo = try container.decode(IdentityProviderInfo.self, forKey: .ipInfo)
        arsInfos = try container.decode([String: AnonymityRevokerInfo].self, forKey: .arsInfos).reduce(into: [:]) { res, e in
            guard let key = UInt32(e.key) else {
                throw DecodingError.dataCorruptedError(forKey: .arsInfos, in: container, debugDescription: "invalid key index")
            }
            res[key] = e.value
        }
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }

    public struct IdentityProviderInfo: Decodable {
        public var ipIdentity: IdentityProviderID
        public var ipDescription: Description
        public var ipCdiVerifyKey: String
        public var ipVerifyKey: String

        public func toSDKType() -> Concordium.IdentityProviderInfo {
            .init(
                identity: ipIdentity,
                description: ipDescription,
                verifyKeyHex: ipVerifyKey,
                cdiVerifyKeyHex: ipCdiVerifyKey
            )
        }
    }

    public struct AnonymityRevokerInfo: Decodable {
        public var arIdentity: AnonymityRevokerID
        public var arDescription: Description
        public var arPublicKey: String

        public func toSDKType() -> Concordium.AnonymityRevokerInfo {
            .init(
                identity: arIdentity,
                description: arDescription,
                publicKeyHex: arPublicKey
            )
        }
    }

    public func toSDKType() -> IdentityProvider {
        .init(
            info: ipInfo.toSDKType(),
            metadata: metadata,
            anonymityRevokers: arsInfos.mapValues { $0.toSDKType() }
        )
    }
}
