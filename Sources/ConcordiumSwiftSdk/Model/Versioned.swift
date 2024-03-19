import Foundation

public struct Versioned<V> {
    public var version: UInt32
    public var value: V

    public init(version: UInt32, value: V) {
        self.version = version
        self.value = value
    }
}
