import CryptoKit
import Foundation

public struct HTTPRequest<Response: Decodable> {
    public var request: URLRequest

    public init(request: URLRequest) {
        self.request = request
    }

    public init(url: URL) {
        self.init(request: URLRequest(url: url))
    }

    func decodeResponse(data: Data) throws -> Response {
        try JSONDecoder().decode(Response.self, from: data)
    }

    func send(session: URLSession = URLSession.shared) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(URLError.Code(rawValue: httpResponse.statusCode))
        }
        return data
    }

    public func send(session: URLSession = URLSession.shared) async throws -> Response {
        let data: Data = try await send(session: session)
        return try decodeResponse(data: data)
    }

    public func send(session: URLSession = URLSession.shared, checkSHA256 checksum: Data) async throws -> Response {
        let data: Data = try await send(session: session)
        let hash = SHA256.hash(data: data)
        guard hash == checksum else { throw URLError(.badServerResponse) }
        return try decodeResponse(data: data)
    }
}
