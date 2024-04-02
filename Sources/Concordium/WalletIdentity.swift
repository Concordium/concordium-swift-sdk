import Foundation

public enum IdentityRequestError: Error {
    case issuanceNotSupported
    case cannotConstructIssuanceURL
    case cannotConstructRecoveryURL
}

public typealias IdentityIssuanceRequest = HTTPRequest<IdentityIssuanceResponse>
public typealias IdentityRecoverRequest = HTTPRequest<Versioned<IdentityObject>>

public class IdentityRequestURLBuilder {
    private let callbackURL: URL? // Android example wallet uses: concordiumwallet-example://identity-issuer/callback

    // If callback URL is nil then only recovery is supported.
    public init(callbackURL: URL?) {
        self.callbackURL = callbackURL
    }

    // Returned URL will go through identity flow (or produce error) and eventually produce URL from where you can fetch identity object.
    // To be decoded as `IdentityIssuanceResponse`.
    public func issuanceURLToOpen(baseURL: URL, requestJSON: String) throws -> URL {
        try issuanceURL(baseURL: baseURL, requestJSON: requestJSON) ?! IdentityRequestError.cannotConstructIssuanceURL
    }

    private func issuanceURL(baseURL: URL, requestJSON: String) throws -> URL? {
        guard let redirectURI = callbackURL else {
            throw IdentityRequestError.issuanceNotSupported
        }
        // FUTURE: The URL method 'appending(queryItems:)' is nicer but requires bumping supported platforms.
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: "identity"),
            URLQueryItem(name: "state", value: requestJSON),
        ]
        return components.url
    }

    public func recoveryRequestToFetch(baseURL: URL, requestJSON: String) throws -> IdentityRecoverRequest {
        let url = try recoveryRequestURL(baseURL: baseURL, requestJSON: requestJSON) ?! IdentityRequestError.cannotConstructRecoveryURL
        return HTTPRequest(url: url)
    }

    private func recoveryRequestURL(baseURL: URL, requestJSON: String) -> URL? {
        // FUTURE: The URL method 'appending(queryItems:)' is nicer but requires bumping supported platforms.
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "state", value: requestJSON),
        ]
        return components.url
    }
}
