//
//  File.swift
//  Concordium
//
//  Created by Max on 30.07.2025.
//

import Foundation
import BigInt
import SwiftCBOR
import NIO

public enum TokenUpdateOperation: Equatable {
    case transfer(ConfigureTransferPLTPayload)

    public func toCBOR() -> CBOR {
        switch self {
        case .transfer(let payload):
            return payload.asCBOR()
        }
    }

    public func toCBORData() -> Data { Data(toCBOR().encode()) }
}


extension AccountTransaction {
    public static func transfer(
        plt tokenId: String,
        sender: AccountAddress,
        receiver: AccountAddress,
        amount: Amount,
        memo: Memo? = nil
    ) -> Self {
        let tokenAmount = PLT.TokenOperationAmount(amount: amount)
        let recipient = PLT.TaggedTokenHolderAccount(accountAddress: PLT.AccountAddress(data: receiver.data))
        let memoPayload = memo.flatMap { PLT.CborMemo(cborObject: .utf8String($0.stringValue)) }

        let transferPayload = ConfigureTransferPLTPayload(
            amount: tokenAmount,
            receiver: recipient,
            memo: memoPayload
        )

        return AccountTransaction(
            sender: sender,
            payload: .updatePLT(
                tokenId: tokenId,
                operation: .transfer(transferPayload)
            ),
            energy: TransactionCost.TRANSFER
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
        var innerMap: [CBOR: CBOR] = [
            .utf8String("amount"): amount.asCBOR(),
            .utf8String("recipient"): receiver.asCBOR()
        ]
        if let memo {
            innerMap[.utf8String("memo")] = memo.asCBOR()
        }

        return .map([
            .utf8String("transfer"): CBOR.map(innerMap)
        ])
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
    }

    public struct TaggedTokenHolderAccount: Equatable, Hashable, Codable {
        public static let cborTag = CBOR.Tag(rawValue: 40307)
        private static let fieldId: UInt64 = 3

        public let data: [UInt8]

        public init(accountAddress: AccountAddress) {
            self.data = accountAddress.bytes
        }

        public init(data: [UInt8]) {
            self.data = data
        }

        public func asCBOR() -> CBOR {
            .tagged(Self.cborTag, .map([
                .unsignedInt(Self.fieldId): .byteString(data)
            ]))
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
            self.content = encoded
        }
        
        public init?(string: String) {
            let cbor = CBOR.utf8String(string)
            let encoded = cbor.encode()
            guard encoded.count <= Self.maxLength else { return nil }
            self.content = encoded
        }

        public func asCBOR() -> CBOR {
            .tagged(Self.tag, .byteString(content))
        }
    }

    public struct AccountAddress: Equatable, Hashable {
        public let bytes: [UInt8]

        public init(bytes: [UInt8]) {
            self.bytes = bytes
        }

        public init(data: Data) {
            self.bytes = Array(data)
        }

        public init?(hex: String) {
            var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("0x") { s.removeFirst(2) }
            guard s.count % 2 == 0 else { return nil }

            var out: [UInt8] = []
            var idx = s.startIndex
            while idx < s.endIndex {
                let next = s.index(idx, offsetBy: 2)
                guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
                out.append(b)
                idx = next
            }
            self.bytes = out
        }

        public var data: Data { Data(bytes) }
    }
}

extension String: Serialize {
    public func serialize(into buffer: inout ByteBuffer) -> Int {
        let bytes = Array(self.utf8)
        var res = 0
        res += buffer.writeInteger(UInt8(bytes.count)) // 1-byte length prefix
        res += buffer.writeBytes(bytes)
        return res
    }
}
