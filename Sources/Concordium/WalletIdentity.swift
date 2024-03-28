import Foundation

public enum IdentityRequestError: Error {
    case issuanceNotSupported
    case cannotConstructIssuanceUrl
    case cannotConstructRecoveryUrl
}

public typealias IdentityIssuanceRequest = HTTPRequest<IdentityIssuanceResponse>
public typealias IdentityRecoverRequest = HTTPRequest<Versioned<IdentityObject>>

public class IdentityRequestUrlBuilder {
    private let callbackUrl: URL? // In Android example wallet: concordiumwallet-example://identity-issuer/callback

    // If callback URL is nil then only recovery is supported.
    public init(callbackUrl: URL?) {
        self.callbackUrl = callbackUrl
    }

    // Returned URL will go through identity flow (or produce error) and eventually produce URL from where you can fetch identity object.
    // To be decoded as `IdentityIssuanceResponse`.
    public func issuanceUrlToOpen(baseUrl: URL, requestJson: String) throws -> URL {
        try issuanceUrl(baseUrl: baseUrl, requestJson: requestJson) ?! IdentityRequestError.cannotConstructIssuanceUrl
    }

    private func issuanceUrl(baseUrl: URL, requestJson: String) throws -> URL? {
        guard let redirectUri = callbackUrl else {
            throw IdentityRequestError.issuanceNotSupported
        }
        // FUTURE: The URL method 'appending(queryItems:)' is nicer but requires bumping supported platforms.
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri.absoluteString),
            URLQueryItem(name: "scope", value: "identity"),
            URLQueryItem(name: "state", value: requestJson),
        ]
        return components.url
    }

    public func recoveryRequestToFetch(baseUrl: URL, requestJson: String) throws -> IdentityRecoverRequest {
        let url = try recoveryRequestUrl(baseUrl: baseUrl, requestJson: requestJson) ?! IdentityRequestError.cannotConstructRecoveryUrl
        return HTTPRequest(url: url)
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
