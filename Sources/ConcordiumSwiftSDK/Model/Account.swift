import Foundation
import Base58Check

fileprivate let accountAddressBase58CheckVersionByte: UInt8 = 1

struct AccountAddress {
    let bytes: Data // 32 bytes
    
    /// Construct address from the standard representation (Base58Check).
    init(base58Check: String) throws {
        let bytes = try Base58Check().decode(string: base58Check)
        let versionByte = bytes[0]
        if versionByte != accountAddressBase58CheckVersionByte {
            throw GrpcError.unexpectedBase64CheckVersionByte(expected: accountAddressBase58CheckVersionByte, actual: versionByte)
        }
        self.bytes = bytes[1...] // exclude initial version byte
    }
}
typealias SequenceNumber = UInt64

struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber
    let allFinal: Bool
}
