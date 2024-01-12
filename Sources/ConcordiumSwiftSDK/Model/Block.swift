import Foundation

typealias BlockHash = Data // 32 bytes

enum BlockIdentifier {
    case lastFinal
    case best
    case hash(BlockHash)
    case absoluteHeight(height: UInt64)
    case relativeHeight(genesisIndex: UInt32, height: UInt64, restrictedToGenesisIndex: Bool)

    func toGrpcType() -> Concordium_V2_BlockHashInput {
        switch self {
        case .lastFinal:
            var b = Concordium_V2_BlockHashInput()
            b.lastFinal = Concordium_V2_Empty()
            return b
        case .best:
            var b = Concordium_V2_BlockHashInput()
            b.best = Concordium_V2_Empty()
            return b
        case .hash(let hash):
            var h = Concordium_V2_BlockHash()
            h.value = hash
            var b = Concordium_V2_BlockHashInput()
            b.given = h
            return b
        case let .absoluteHeight(height):
            var h = Concordium_V2_AbsoluteBlockHeight()
            h.value = height
            var b = Concordium_V2_BlockHashInput()
            b.absoluteHeight = h
            return b
        case let .relativeHeight(genesisIndex, height, restrictedToGenesisIndex):
            var h = Concordium_V2_BlockHashInput.RelativeHeight()
            var gh = Concordium_V2_GenesisIndex()
            gh.value = genesisIndex
            var bh = Concordium_V2_BlockHeight()
            bh.value = height
            h.genesisIndex = gh
            h.height = bh
            h.restrict = restrictedToGenesisIndex
            var b = Concordium_V2_BlockHashInput()
            b.relativeHeight = h
            return b
        }
    }
}

typealias TransactionHash = Data // 32 bytes (SHA256)
