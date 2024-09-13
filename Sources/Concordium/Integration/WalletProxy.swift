import Foundation

public enum WalletProxyError: Error {
    case cannotConstructURL
}

public class WalletProxy {
    let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public var getIdentityProviders: HTTPRequest<[IdentityProviderJSON]> {
        get throws {
            try HTTPRequest(url: URL(string: "/v1/ip_info", relativeTo: baseURL) ?! WalletProxyError.cannotConstructURL)
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

        public func toSDKType() throws -> Concordium.IdentityProviderInfo {
            try .init(
                identity: ipIdentity,
                description: ipDescription,
                verifyKey: Data(hex: ipVerifyKey),
                cdiVerifyKey: Data(hex: ipCdiVerifyKey)
            )
        }
    }

    public struct AnonymityRevokerInfo: Decodable {
        public var arIdentity: AnonymityRevokerID
        public var arDescription: Description
        public var arPublicKey: String

        public func toSDKType() throws -> Concordium.AnonymityRevokerInfo {
            try .init(
                identity: arIdentity,
                description: arDescription,
                publicKey: Data(hex: arPublicKey)
            )
        }
    }

    public func toSDKType() throws -> IdentityProvider {
        try .init(
            info: ipInfo.toSDKType(),
            metadata: metadata,
            anonymityRevokers: arsInfos.mapValues { try $0.toSDKType() }
        )
    }
}
