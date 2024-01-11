import Foundation
import Base58Check

fileprivate let accountAddressBase58CheckVersion: UInt8 = 1

struct AccountAddress {
    let bytes: Data // 32 bytes (Base58Check without version byte)
    
    init(base58Check: String) throws {
        let bytes = try Base58Check().decode(string: base58Check)
        let v = bytes[0]
        if v != accountAddressBase58CheckVersion {
            throw GrpcError.unexpectedBase64CheckVersionByte(expected: accountAddressBase58CheckVersion, actual: v)
        }
        self.bytes = bytes[1...] // exclude initial version byte
    }
}
typealias SequenceNumber = UInt64

struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber
    let allFinal: Bool
}
