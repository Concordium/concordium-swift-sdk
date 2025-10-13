//
//  Transaction+PLT.swift
//  Concordium
//
//  Created by Max on 30.07.2025.
//

import BigInt
import Foundation
import NIO
import SwiftCBOR

/// A protocol-level token (PLT) operation used in TokenUpdate
public protocol TokenOperation {
    /// Operation type name, e.g. "transfer", "mint", etc.
    var type: String { get }

    /// A CBOR-serializable operation body
    var body: CBOR { get }

    /// The base energy cost of this operation
    var baseCost: Energy { get }
}

public enum TokenUpdateOperation: Equatable, TokenOperation {
    case transfer(ConfigureTransferPLTPayload)

    public var type: String {
        switch self {
        case .transfer:
            return "transfer"
        }
    }

    public var body: CBOR {
        switch self {
        case let .transfer(payload):
            return payload.asCBOR()
        }
    }

    public var baseCost: Energy {
        switch self {
        case .transfer:
            return Energy(100)
        }
    }

    public func toCBOR() -> CBOR {
        .map([.utf8String(type): body])
    }

    public func toCBORList() -> CBOR {
        .array([toCBOR()])
    }

    public func toCBORData() -> Data { Data(toCBOR().encode()) }
}

/// A protocol-level token (PLT) transaction payload containing operations
public struct TokenUpdate: Equatable {
    /// Symbol (ID) of the token to execute operations on
    public let tokenSymbol: String

    /// Operations to execute
    public let operations: [TokenUpdateOperation]

    public init(tokenSymbol: String, operations: [TokenUpdateOperation]) {
        self.tokenSymbol = tokenSymbol
        self.operations = operations
    }

    /// Get the total base cost for all operations
    public func getOperationsBaseCost() -> Energy {
        var total = Energy(0)
        for operation in operations {
            total += operation.baseCost
        }
        return total
    }
}

public extension TokenUpdateOperation {
    static func fromCBORData(_ data: Data) -> TokenUpdateOperation? {
        guard let cbor = try? CBOR.decode(Array(data)) else { return nil }
        return fromCBOR(cbor)
    }

    static func fromCBOR(_ cbor: CBOR) -> TokenUpdateOperation? {
        guard case let .map(map) = cbor else { return nil }

        if let transferData = map[.utf8String("transfer")] {
            guard case let .map(transferMap) = transferData else { return nil }

            guard let amountData = transferMap[.utf8String("amount")],
                  let receiverData = transferMap[.utf8String("recipient")] else { return nil }

            guard let amount = PLT.TokenOperationAmount.fromCBOR(amountData),
                  let receiver = PLT.TaggedTokenHolderAccount.fromCBOR(receiverData) else { return nil }

            let memo = transferMap[.utf8String("memo")].flatMap { PLT.CborMemo.fromCBOR($0) }

            let payload = ConfigureTransferPLTPayload(
                amount: amount,
                receiver: receiver,
                memo: memo
            )
            return .transfer(payload)
        }

        return nil
    }
}

public extension AccountTransaction {
    static func transfer(
        plt tokenId: String,
        sender: AccountAddress,
        receiver: AccountAddress,
        amount: Amount,
        memo: Memo? = nil
    ) -> Self {
        let tokenAmount = PLT.TokenOperationAmount(amount: amount)
        let recipient = PLT.TaggedTokenHolderAccount(accountAddress: PLT.AccountAddress(data: receiver.data))
        let memoPayload = memo.flatMap { PLT.CborMemo(string: $0.stringValue) }

        let transferPayload = ConfigureTransferPLTPayload(
            amount: tokenAmount,
            receiver: recipient,
            memo: memoPayload
        )

        let energy = TransactionCost.pltTransferCost(tokenId: tokenId, operation: .transfer(transferPayload))

        return AccountTransaction(
            sender: sender,
            payload: .updatePLT(
                tokenId: tokenId,
                operation: .transfer(transferPayload)
            ),
            energy: energy
        )
    }
}

public struct ConfigureTransferPLTPayload: Equatable, Codable {
    public let amount: PLT.TokenOperationAmount
    public let receiver: PLT.TaggedTokenHolderAccount
    public let memo: PLT.CborMemo?

    public init(
        amount: PLT.TokenOperationAmount,
        receiver: PLT.TaggedTokenHolderAccount,
        memo: PLT.CborMemo? = nil
    ) {
        self.amount = amount
        self.receiver = receiver
        self.memo = memo
    }

    public func toCBORData() -> Data {
        Data(asCBOR().encode())
    }

    public func asCBOR() -> CBOR {
        var operationMap: [CBOR: CBOR] = [
            .utf8String("amount"): amount.asCBOR(),
            .utf8String("recipient"): receiver.asCBOR(),
        ]
        if let memo {
            operationMap[.utf8String("memo")] = memo.asCBOR()
        }

        return .map(operationMap)
    }
}

public enum PLT {
    public struct TokenOperationAmount: Equatable, Hashable, Codable {
        public let value: BigUInt
        public let decimals: Int
        public static let tag = CBOR.Tag(rawValue: 4)

        public init(value: BigUInt, decimals: Int) {
            precondition(decimals >= 0)
            self.value = value
            self.decimals = decimals
        }

        public init(amount: Amount) {
            self.init(value: amount.value, decimals: Int(amount.decimalCount))
        }

        public func asCBOR() -> CBOR {
            let exponent = CBOR.negativeInt(UInt64(decimals - 1))
            let mantissa: CBOR = UInt64(exactly: value)
                .map(CBOR.unsignedInt) ?? .byteString(Array(value.serialize()))
            return .tagged(Self.tag, .array([exponent, mantissa]))
        }

        public static func fromCBOR(_ cbor: CBOR) -> TokenOperationAmount? {
            guard case let .tagged(tag, .array(array)) = cbor,
                  tag == Self.tag,
                  array.count == 2 else { return nil }

            let exponent: Int
            let mantissa: BigUInt

            switch array[0] {
            case let .negativeInt(negInt):
                exponent = Int(negInt)
            case let .unsignedInt(posInt):
                exponent = -Int(posInt)
            default:
                return nil
            }

            switch array[1] {
            case let .unsignedInt(uint):
                mantissa = BigUInt(uint)
            case let .byteString(bytes):
                mantissa = BigUInt(Data(bytes))
            default:
                return nil
            }

            let decimals = exponent + 1
            return TokenOperationAmount(value: mantissa, decimals: decimals)
        }
    }

    public struct TaggedTokenHolderAccount: Equatable, Hashable, Codable {
        public static let cborTag = CBOR.Tag(rawValue: 40307)
        private static let fieldId: UInt64 = 3

        public let data: [UInt8]

        public init(accountAddress: AccountAddress) {
            data = accountAddress.bytes
        }

        public init(data: [UInt8]) {
            self.data = data
        }

        public func asCBOR() -> CBOR {
            .tagged(Self.cborTag, .map([
                .unsignedInt(Self.fieldId): .byteString(data),
            ]))
        }

        public static func fromCBOR(_ cbor: CBOR) -> TaggedTokenHolderAccount? {
            guard case let .tagged(tag, .map(map)) = cbor,
                  tag == cborTag,
                  case let .byteString(data) = map[.unsignedInt(fieldId)] else { return nil }
            return TaggedTokenHolderAccount(data: data)
        }
    }

    public struct CborMemo: Equatable, Hashable, Codable {
        public static let tag = CBOR.Tag(rawValue: 24)
        public static let maxLength = 256

        public let content: [UInt8]

        public init?(rawCBOR content: [UInt8]) {
            guard content.count <= Self.maxLength else { return nil }
            self.content = content
        }

        public init?(data: Data) {
            self.init(rawCBOR: Array(data))
        }

        public init?(cborObject: CBOR) {
            let encoded = cborObject.encode()
            guard encoded.count <= Self.maxLength else { return nil }
            content = encoded
        }

        public init?(string: String) {
            let stringBytes = Array(string.utf8)
            guard stringBytes.count <= Self.maxLength else { return nil }
            content = stringBytes
        }

        public func asCBOR() -> CBOR {
            .tagged(Self.tag, .byteString(content))
        }

        public static func fromCBOR(_ cbor: CBOR) -> CborMemo? {
            guard case let .tagged(tag, .byteString(content)) = cbor,
                  tag == Self.tag else { return nil }
            return CborMemo(rawCBOR: content)
        }
    }

    public struct AccountAddress: Equatable, Hashable {
        public let bytes: [UInt8]

        public init(bytes: [UInt8]) {
            self.bytes = bytes
        }

        public init(data: Data) {
            bytes = Array(data)
        }

        public init?(hex: String) {
            var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("0x") { s.removeFirst(2) }
            guard s.count % 2 == 0 else { return nil }

            var out: [UInt8] = []
            var idx = s.startIndex
            while idx < s.endIndex {
                let next = s.index(idx, offsetBy: 2)
                guard let b = UInt8(s[idx ..< next], radix: 16) else { return nil }
                out.append(b)
                idx = next
            }
            bytes = out
        }

        public var data: Data { Data(bytes) }
    }
}

extension String: Serialize, Deserialize {
    public func serialize(into buffer: inout ByteBuffer) -> Int {
        let bytes = Array(utf8)
        var res = 0
        res += buffer.writeInteger(UInt8(bytes.count)) // 1-byte length prefix
        res += buffer.writeBytes(bytes)
        return res
    }

    public static func deserialize(_ data: inout Cursor) -> String? {
        guard let length = data.parseUInt(UInt8.self),
              let bytes = data.read(num: length) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }
}
