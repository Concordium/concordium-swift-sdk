import Foundation

public struct Versioned<V> {
    public var version: UInt32
    public var value: V

    public init(version: UInt32, value: V) {
        self.version = version
        self.value = value
    }
}

extension Versioned: Decodable where V: Decodable {
    enum CodingKeys: CodingKey {
        case v
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            version: container.decode(UInt32.self, forKey: .v),
            value: container.decode(V.self, forKey: .value)
        )
    }
}
