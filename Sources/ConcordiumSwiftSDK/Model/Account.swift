import Foundation
import Base58Check

fileprivate let accountAddressBase58CheckVersion: UInt8 = 1

struct AccountAddress {
    let bytes: Data // 32 bytes
    
    /// Construct address from the standard representation (Base58Check).
    init(base58Check: String) throws {
        var bytes = try Base58Check().decode(string: base58Check)
        let version = bytes.removeFirst()
        if version != accountAddressBase58CheckVersion {
            throw GrpcError.unexpectedBase64CheckVersion(expected: accountAddressBase58CheckVersion, actual: version)
        }
        self.bytes = bytes // excludes initial version byte
    }
}
typealias SequenceNumber = UInt64

struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber
    let allFinal: Bool
}
