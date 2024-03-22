import Foundation

public struct HttpRequest<Response: Decodable> {
    public var request: URLRequest

    public init(request: URLRequest) {
        self.request = request
    }

    public init(url: URL) {
        self.init(request: URLRequest(url: url))
    }
}

public extension HttpRequest {
    func decodeResponse(data: Data) throws -> Response {
        try JSONDecoder().decode(Response.self, from: data)
    }

    func response(session: URLSession) async throws -> Response {
        let (data, _) = try await session.data(for: request)
        return try decodeResponse(data: data)
    }
}
