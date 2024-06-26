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

    public func send(session: URLSession) async throws -> Response {
        let (data, _) = try await session.data(for: request)
        return try decodeResponse(data: data)
    }
}
