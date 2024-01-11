import Foundation

typealias AccountAddress = Data // 32 bytes
typealias SequenceNumber = UInt64

struct NextAccountSequenceNumber {
    let sequenceNumber: SequenceNumber
    let allFinal: Bool
}
