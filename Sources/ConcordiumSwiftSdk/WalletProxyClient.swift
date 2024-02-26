import Foundation

public class WalletProxyClient {
    let baseUrl: String

    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    public func getIdentityProviderInfo() async throws -> [IdentityProviderJson] {
        let url = URL(string: "\(baseUrl)/v1/ip_info")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([IdentityProviderJson].self, from: data)
    }
}

public struct IdentityProviderJson: Decodable {
    public var ipInfo: IdentityProvider
    public var arsInfos: [String: AnonymityRevoker]
    public var metadata: Metadata

    public struct IdentityProvider: Decodable {
        public var ipIdentity: UInt32
        public var ipDescription: Description
        public var ipCdiVerifyKey: String
        public var ipVerifyKey: String
    }

    public struct AnonymityRevoker: Decodable {
        public var arIdentity: UInt32
        public var arDescription: Description
        public var arPublicKey: String
    }

    public struct Description: Decodable {
        public var name: String
        public var description: String
        public var url: String
    }

    public struct Metadata: Decodable {
        public var icon: String
        public var issuanceStart: String
        public var support: String?
        public var recoveryStart: String
    }
}
