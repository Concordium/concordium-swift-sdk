import BigInt
import ConcordiumWalletCrypto
import CryptoKit
import Foundation
import NIO

/// Transaction header V1 with sponsor support
/// This extends the standard header with an optional sponsor account address
public struct AccountTransactionHeaderV1: Serialize, Deserialize {
    /// Sender of the transaction
    public var sender: AccountAddress
    /// Account nonce (sequence number)
    public var nonce: SequenceNumber
    /// Maximum energy amount
    public var maxEnergy: Energy
    /// Payload size in bytes
    public var payloadSize: UInt32
    /// Transaction expiry time
    public var expiry: TransactionTime
    /// Sponsor account address (V1 specific, optional)
    public var sponsor: AccountAddress?

    public init(
        sender: AccountAddress,
        nonce: SequenceNumber,
        maxEnergy: Energy,
        payloadSize: UInt32,
        expiry: TransactionTime,
        sponsor: AccountAddress? = nil
    ) {
        self.sender = sender
        self.nonce = nonce
        self.maxEnergy = maxEnergy
        self.payloadSize = payloadSize
        self.expiry = expiry
        self.sponsor = sponsor
    }

    /// Convert to standard AccountTransactionHeader (without sponsor)
    public func toAccountTransactionHeader() -> AccountTransactionHeader {
        AccountTransactionHeader(
            sender: sender,
            sequenceNumber: nonce,
            maxEnergy: maxEnergy,
            expiry: expiry
        )
    }

    /// Create from standard AccountTransactionHeader
    public static func from(header: AccountTransactionHeader, sponsor: AccountAddress? = nil) -> AccountTransactionHeaderV1 {
        AccountTransactionHeaderV1(
            sender: header.sender,
            nonce: header.sequenceNumber,
            maxEnergy: header.maxEnergy,
            payloadSize: 0, // Will be set when serializing
            expiry: header.expiry,
            sponsor: sponsor
        )
    }

    // MARK: - Serialize

    public func serialize(into buffer: inout ByteBuffer) -> Int {
        var res = 0

        // Serialize bitmap (2 bytes, UInt16) - bit 0 indicates sponsor presence
        var bitmap: UInt16 = 0
        if sponsor != nil {
            bitmap = bitmap | 1
        }
        res += buffer.writeInteger(bitmap, endianness: .big, as: UInt16.self)

        // Serialize standard header fields
        res += buffer.writeData(sender.data)
        res += buffer.writeInteger(nonce, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(maxEnergy, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(payloadSize, endianness: .big, as: UInt32.self)
        res += buffer.writeInteger(expiry, endianness: .big, as: UInt64.self)

        // Serialize sponsor if present (32 bytes address)
        if let sponsor = sponsor {
            res += buffer.writeData(sponsor.data)
        }

        return res
    }

    // MARK: - Deserialize

    public static func deserialize(_ data: inout Cursor) -> AccountTransactionHeaderV1? {
        // Read bitmap (2 bytes, UInt16) - bit 0 indicates sponsor presence
        guard let bitmap = data.parseUInt(UInt16.self, endianness: .big) else { return nil }
        let hasSponsor = (bitmap & 1) != 0

        // Read sender (32 bytes)
        guard let sender = AccountAddress.deserialize(&data) else { return nil }

        // Read nonce (8 bytes, big endian)
        guard let nonce = data.parseUInt(UInt64.self, endianness: .big) else { return nil }

        // Read maxEnergy (8 bytes, big endian)
        guard let maxEnergy = data.parseUInt(UInt64.self, endianness: .big) else { return nil }

        // Read payloadSize (4 bytes, big endian)
        guard let payloadSize = data.parseUInt(UInt32.self, endianness: .big) else { return nil }

        // Read expiry (8 bytes, big endian)
        guard let expiry = data.parseUInt(UInt64.self, endianness: .big) else { return nil }

        // Read sponsor if present (32 bytes)
        var sponsor: AccountAddress? = nil
        if hasSponsor {
            guard let sponsorAddr = AccountAddress.deserialize(&data) else { return nil }
            sponsor = sponsorAddr
        }

        return AccountTransactionHeaderV1(
            sender: sender,
            nonce: SequenceNumber(nonce),
            maxEnergy: Energy(maxEnergy),
            payloadSize: payloadSize,
            expiry: TransactionTime(expiry),
            sponsor: sponsor
        )
    }

    /// Decode from hex string
    public static func decode(from hexString: String) throws -> AccountTransactionHeaderV1 {
        guard let data = try? Data(hex: hexString) else {
            throw DeserializeError(AccountTransactionHeaderV1.self, data: Data())
        }
        var cursor = Cursor(data: data)
        guard let header = deserialize(&cursor) else {
            throw DeserializeError(AccountTransactionHeaderV1.self, data: data)
        }
        return header
    }
}

/// Helper for deserializing TransactionSignature from hex-encoded bytes
public extension Signatures {
    /// Decode TransactionSignature from hex-encoded bytes
    /// TransactionSignature structure:
    /// UInt8: number of credentials
    /// For each credential:
    ///   UInt8: credential index
    ///   UInt8: number of keys
    ///   For each key:
    ///     UInt8: key index
    ///     Signature: UInt16 length + bytes
    static func decode(from hexString: String) throws -> Signatures {
        guard let data = try? Data(hex: hexString) else {
            throw DeserializeError(Signatures.self, data: Data())
        }
        return try decode(from: data)
    }

    /// Decode TransactionSignature from raw bytes
    static func decode(from data: Data) throws -> Signatures {
        var cursor = Cursor(data: data)
        var signatures: Signatures = [:]

        // Read the number of credential entries (UInt8)
        guard let numCredentials = cursor.parseUInt(UInt8.self) else {
            throw DeserializeError(Signatures.self, data: data)
        }

        for _ in 0..<numCredentials {
            // Read credential index (UInt8)
            guard let credIndexValue = cursor.parseUInt(UInt8.self) else {
                throw DeserializeError(Signatures.self, data: data)
            }
            let credIndex = CredentialIndex(credIndexValue)

            // Read number of keys for this credential (UInt8)
            guard let numKeys = cursor.parseUInt(UInt8.self) else {
                throw DeserializeError(Signatures.self, data: data)
            }

            var credSignatures: CredentialSignatures = [:]

            for _ in 0..<numKeys {
                // Read key index (UInt8)
                guard let keyIndexValue = cursor.parseUInt(UInt8.self) else {
                    throw DeserializeError(Signatures.self, data: data)
                }
                let keyIndex = KeyIndex(keyIndexValue)

                // Read signature length (UInt16, big endian)
                guard let sigLength = cursor.parseUInt(UInt16.self, endianness: .big) else {
                    throw DeserializeError(Signatures.self, data: data)
                }

                // Read signature bytes
                guard let signatureData = cursor.read(num: sigLength) else {
                    throw DeserializeError(Signatures.self, data: data)
                }

                credSignatures[keyIndex] = signatureData
            }

            signatures[credIndex] = credSignatures
        }

        return signatures
    }
}

/// Prepared sponsored transaction ready for signing
public struct PreparedSponsoredTransaction {
    /// The transaction header V1 (with sponsor)
    public var header: AccountTransactionHeaderV1
    /// The serialized payload (use as-is, don't re-encode)
    public var serializedPayload: Data

    public init(header: AccountTransactionHeaderV1, serializedPayload: Data) {
        self.header = header
        self.serializedPayload = serializedPayload
    }

    /// Compute the transaction hash for signing
    /// Computes the hash that should be signed for the transaction
    /// For V1 transactions, a 32-byte version prefix is prepended before hashing
    public func transactionHash() -> Data {
        // Serialize header with correct payload size
        var headerBuffer = ByteBuffer()
        var headerWithSize = header
        headerWithSize.payloadSize = UInt32(serializedPayload.count)
        _ = headerWithSize.serialize(into: &headerBuffer)

        let headerData = Data(buffer: headerBuffer)

        // V1 transaction hash includes a 32-byte version prefix
        // Last byte is 1 (version 1), all others are 0
        var versionPrefix = Data(count: 32)
        versionPrefix[31] = 1

        // Combine: version prefix + header + payload
        let transactionBytes = versionPrefix + headerData + serializedPayload

        // Hash
        return Data(SHA256.hash(data: transactionBytes))
    }

    /// Convert to standard PreparedAccountTransaction (for submission)
    public func toPreparedAccountTransaction() -> PreparedAccountTransaction {
        PreparedAccountTransaction(
            header: header.toAccountTransactionHeader(),
            serializedPayload: serializedPayload
        )
    }
}

/// Transaction signatures V1 structure for sponsored transactions
/// Contains separate sender and sponsor signatures
public struct TransactionSignaturesV1 {
    /// The signature on the transaction by the source account
    public let senderSignature: Signatures
    /// The optional signature on the transaction by the sponsor account
    public let sponsorSignature: Signatures?

    public init(senderSignature: Signatures, sponsorSignature: Signatures?) {
        self.senderSignature = senderSignature
        self.sponsorSignature = sponsorSignature
    }

    /// Create from combined Signatures map
    /// This assumes sender and sponsor use different credential/key indices
    public static func fromCombined(_ combined: Signatures, senderCredentialIndices: Set<CredentialIndex>) -> TransactionSignaturesV1 {
        var senderSigs: Signatures = [:]
        var sponsorSigs: Signatures = [:]

        for (credIndex, credSigs) in combined {
            if senderCredentialIndices.contains(credIndex) {
                senderSigs[credIndex] = credSigs
            } else {
                sponsorSigs[credIndex] = credSigs
            }
        }

        return TransactionSignaturesV1(
            senderSignature: senderSigs,
            sponsorSignature: sponsorSigs.isEmpty ? nil : sponsorSigs
        )
    }

    /// Convert to combined Signatures map (for GRPC submission)
    public func toCombined() -> Signatures {
        var combined = senderSignature
        if let sponsor = sponsorSignature {
            for (credIndex, credSigs) in sponsor {
                if combined[credIndex] == nil {
                    combined[credIndex] = credSigs
                } else {
                    var merged = combined[credIndex]!
                    for (keyIndex, sig) in credSigs {
                        merged[keyIndex] = sig
                    }
                    combined[credIndex] = merged
                }
            }
        }
        return combined
    }

    /// Serialize TransactionSignaturesV1 to bytes
    /// Format: senderSignature.getBytes() + (sponsorSignature.getBytes() or [0] if nil)
    public func serialize() -> Data {
        var buffer = ByteBuffer()

        // Serialize sender signature
        serializeSignatures(senderSignature, into: &buffer)

        // Serialize sponsor signature (or single 0 byte if nil)
        if let sponsor = sponsorSignature {
            serializeSignatures(sponsor, into: &buffer)
        } else {
            buffer.writeInteger(UInt8(0), endianness: .big, as: UInt8.self)
        }

        return Data(buffer: buffer)
    }

    /// Helper to serialize Signatures to TransactionSignature format
    private func serializeSignatures(_ signatures: Signatures, into buffer: inout ByteBuffer) {
        // Write number of credentials (UInt8)
        buffer.writeInteger(UInt8(signatures.count), endianness: .big, as: UInt8.self)

        // Sort by credential index for consistent serialization
        let sortedCreds = signatures.sorted { $0.key < $1.key }

        for (credIndex, credSigs) in sortedCreds {
            // Write credential index (UInt8)
            buffer.writeInteger(UInt8(credIndex), endianness: .big, as: UInt8.self)

            // Write number of keys (UInt8)
            buffer.writeInteger(UInt8(credSigs.count), endianness: .big, as: UInt8.self)

            // Sort by key index for consistent serialization
            let sortedKeys = credSigs.sorted { $0.key < $1.key }

            for (keyIndex, sig) in sortedKeys {
                // Write key index (UInt8)
                buffer.writeInteger(UInt8(keyIndex), endianness: .big, as: UInt8.self)

                // Write signature length (UInt16, big endian)
                buffer.writeInteger(UInt16(sig.count), endianness: .big, as: UInt16.self)

                // Write signature bytes
                buffer.writeData(sig)
            }
        }
    }
}

/// Signed sponsored transaction with both sender and sponsor signatures
public struct SignedSponsoredTransaction {
    /// The prepared transaction
    public var transaction: PreparedSponsoredTransaction
    /// Sender signatures
    public var senderSignatures: Signatures
    /// Sponsor signatures
    public var sponsorSignatures: Signatures

    public init(transaction: PreparedSponsoredTransaction, senderSignatures: Signatures, sponsorSignatures: Signatures) {
        self.transaction = transaction
        self.senderSignatures = senderSignatures
        self.sponsorSignatures = sponsorSignatures
    }

    /// Get TransactionSignaturesV1 structure
    /// Creates TransactionSignaturesV1 from separate sender and sponsor signatures
    public func toTransactionSignaturesV1() -> TransactionSignaturesV1 {
        TransactionSignaturesV1(
            senderSignature: senderSignatures,
            sponsorSignature: sponsorSignatures.isEmpty ? nil : sponsorSignatures
        )
    }

    /// Get combined signatures (for GRPC submission if needed)
    public var signatures: Signatures {
        combineSponsoredSignatures(sender: senderSignatures, sponsor: sponsorSignatures)
    }

    /// Convert to standard SignedAccountTransaction for GRPC submission
    ///
    /// **IMPORTANT**: This method converts the V1 header (with sponsor) to a standard header (without sponsor).
    /// The node should detect sponsored transactions from the signatures and reconstruct the V1 header
    /// for hash computation. However, the node needs the sponsor address to compute the correct hash.
    ///
    /// The sponsor address is available in `transaction.header.sponsor`, but it's lost in the conversion.
    /// The node should be able to infer the sponsor from the signatures (by looking up which account
    /// owns the credentials that signed the sponsor signature), but this may not be implemented yet.
    ///
    /// If verification fails, this may indicate that the node cannot properly detect sponsored transactions
    /// from the standard format. In that case, we may need to:
    /// 1. Update the GRPC proto to support V1 transactions directly, or
    /// 2. Submit the transaction as raw block item bytes (if the proto supports it), or
    /// 3. Ensure the node can properly infer the sponsor from signatures
    public func toSignedAccountTransaction() -> SignedAccountTransaction {
        // Create a PreparedAccountTransaction with the standard header
        // The node will detect the sponsor from the signatures and use V1 format internally
        let prepared = PreparedAccountTransaction(
            header: transaction.header.toAccountTransactionHeader(),
            serializedPayload: transaction.serializedPayload
        )

        return SignedAccountTransaction(
            transaction: prepared,
            signatures: signatures
        )
    }

    /// Serialize as AccountTransactionV1 block item (for direct submission)
    /// Format: BlockItemType (1 byte = 3) + TransactionSignaturesV1 + header + payload
    public func serializeAsBlockItem() -> Data {
        var buffer = ByteBuffer()

        // BlockItemType.ACCOUNT_TRANSACTION_V1 = 3
        buffer.writeInteger(UInt8(3), endianness: .big, as: UInt8.self)

        // Serialize TransactionSignaturesV1 (sender + sponsor signatures)
        let sigsV1 = toTransactionSignaturesV1()
        let sigsV1Bytes = sigsV1.serialize()
        buffer.writeData(sigsV1Bytes)

        // Serialize header (with correct payload size)
        var headerWithSize = transaction.header
        headerWithSize.payloadSize = UInt32(transaction.serializedPayload.count)
        _ = headerWithSize.serialize(into: &buffer)

        // Serialize payload (use as-is, don't re-encode)
        buffer.writeData(transaction.serializedPayload)

        return Data(buffer: buffer)
    }
}

/// Helper for creating sponsored transactions
public extension AccountTransaction {
    /// Create a sponsored transaction from raw header and payload bytes
    /// - Parameters:
    ///   - headerHex: HEX-encoded TransactionHeaderV1 bytes
    ///   - payloadHex: HEX-encoded payload bytes (type byte + payload bytes)
    /// - Returns: PreparedSponsoredTransaction ready for signing
    static func createSponsored(
        headerHex: String,
        payloadHex: String
    ) throws -> PreparedSponsoredTransaction {
        let header = try AccountTransactionHeaderV1.decode(from: headerHex)
        guard let payloadData = try? Data(hex: payloadHex) else {
            throw DeserializeError(AccountTransactionPayload.self, data: Data())
        }

        return PreparedSponsoredTransaction(
            header: header,
            serializedPayload: payloadData
        )
    }

    /// Decode payload from hex-encoded bytes
    /// - Parameter payloadHex: HEX-encoded payload bytes (type byte + payload bytes)
    /// - Returns: Decoded AccountTransactionPayload
    static func decodePayload(from payloadHex: String) throws -> AccountTransactionPayload {
        guard let payloadData = try? Data(hex: payloadHex) else {
            throw DeserializeError(AccountTransactionPayload.self, data: Data())
        }
        var cursor = Cursor(data: payloadData)
        guard let payload = AccountTransactionPayload.deserialize(&cursor) else {
            throw DeserializeError(AccountTransactionPayload.self, data: payloadData)
        }
        return payload
    }
}

/// Validation helpers for sponsored transactions
public enum SponsoredTransactionValidator {
    /// Validate that the transaction sender matches the expected account
    /// - Parameters:
    ///   - header: The transaction header V1
    ///   - expectedSender: The account address that should be the sender
    /// - Throws: ValidationError if sender doesn't match
    public static func validateSender(
        header: AccountTransactionHeaderV1,
        expectedSender: AccountAddress
    ) throws {
        guard header.sender == expectedSender else {
            throw ValidationError.senderMismatch(
                expected: expectedSender,
                actual: header.sender
            )
        }
    }

    /// Validate that the account has sufficient balance for a transfer
    /// - Parameters:
    ///   - payload: The transaction payload
    ///   - accountBalance: The account's available balance in microCCD
    /// - Throws: ValidationError if balance is insufficient
    public static func validateTransferBalance(
        payload: AccountTransactionPayload,
        accountBalance: UInt64
    ) throws {
        switch payload {
        case let .transfer(amount, _, _):
            if amount.microCCD > accountBalance {
                throw ValidationError.insufficientBalance(
                    required: amount.microCCD,
                    available: accountBalance
                )
            }
        default:
            // Other payload types don't require CCD balance validation
            break
        }
    }

    /// Validate that the account has sufficient token balance for a PLT transfer
    /// - Parameters:
    ///   - payload: The transaction payload
    ///   - tokenBalance: The account's available token balance
    /// - Throws: ValidationError if token balance is insufficient
    public static func validatePLTTransferBalance(
        payload: AccountTransactionPayload,
        tokenBalance: BigUInt
    ) throws {
        if case let .updatePLT(_, operation) = payload {
            if case let .transfer(transferPayload) = operation {
                if transferPayload.amount.value > tokenBalance {
                    throw ValidationError.insufficientTokenBalance(
                        required: transferPayload.amount.value,
                        available: tokenBalance
                    )
                }
            }
        }
    }

    /// Validate a sponsored transaction
    /// - Parameters:
    ///   - headerHex: HEX-encoded TransactionHeaderV1 bytes
    ///   - payloadHex: HEX-encoded payload bytes
    ///   - expectedSender: The account address that should be the sender
    ///   - accountBalance: The account's available balance in microCCD (for CCD transfer validation)
    ///   - tokenBalance: The account's available token balance (for PLT transfer validation)
    /// - Returns: Tuple of (header, payload) if validation passes
    /// - Throws: ValidationError or DeserializeError if validation fails
    public static func validate(
        headerHex: String,
        payloadHex: String,
        expectedSender: AccountAddress,
        accountBalance: UInt64? = nil,
        tokenBalance: BigUInt? = nil
    ) throws -> (header: AccountTransactionHeaderV1, payload: AccountTransactionPayload) {
        let header = try AccountTransactionHeaderV1.decode(from: headerHex)
        let payload = try AccountTransaction.decodePayload(from: payloadHex)

        try validateSender(header: header, expectedSender: expectedSender)

        // Validate CCD balance for regular transfers
        if let balance = accountBalance {
            try validateTransferBalance(payload: payload, accountBalance: balance)
        }

        // Validate token balance for PLT transfers
        if let tokenBalance = tokenBalance {
            try validatePLTTransferBalance(payload: payload, tokenBalance: tokenBalance)
        }

        return (header, payload)
    }
}

/// Validation errors for sponsored transactions
public enum ValidationError: Error {
    case senderMismatch(expected: AccountAddress, actual: AccountAddress)
    case insufficientBalance(required: UInt64, available: UInt64)
    case insufficientTokenBalance(required: BigUInt, available: BigUInt)

    public var localizedDescription: String {
        switch self {
        case let .senderMismatch(expected, actual):
            return "Transaction sender (\(actual.base58Check)) does not match expected account (\(expected.base58Check))"
        case let .insufficientBalance(required, available):
            return "Insufficient balance: required \(required) microCCD, available \(available) microCCD"
        case let .insufficientTokenBalance(required, available):
            return "Insufficient token balance: required \(required), available \(available)"
        }
    }
}

/// Helper for signing sponsored transactions
public extension Signer {
    /// Sign a sponsored transaction with sender's keys
    /// The sponsor signature should be added separately
    func sign(sponsoredTransaction: PreparedSponsoredTransaction) throws -> Signatures {
        let hash = sponsoredTransaction.transactionHash()
        return try sign(hash)
    }
}

/// Combine sender and sponsor signatures for a sponsored transaction
/// - Parameters:
///   - sender: Signatures from the sender account
///   - sponsor: Signatures from the sponsor account
/// - Returns: Combined signatures map
public func combineSponsoredSignatures(sender: Signatures, sponsor: Signatures) -> Signatures {
    var combined = sender

    // Add sponsor signatures (they should be on different credentials/keys)
    for (credIndex, credSigs) in sponsor {
        if combined[credIndex] == nil {
            combined[credIndex] = credSigs
        } else {
            // Merge key signatures if credential already exists
            var merged = combined[credIndex]!
            for (keyIndex, sig) in credSigs {
                merged[keyIndex] = sig
            }
            combined[credIndex] = merged
        }
    }

    return combined
}

/// High-level helper for creating and signing sponsored transactions
public enum SponsoredTransactionBuilder {
    /// Create, validate, and sign a sponsored transaction
    /// - Parameters:
    ///   - headerHex: HEX-encoded TransactionHeaderV1 bytes
    ///   - payloadHex: HEX-encoded payload bytes
    ///   - sponsorSignatureHex: HEX-encoded sponsor TransactionSignature
    ///   - signer: Signer for the sender's account
    ///   - expectedSender: The account address that should be the sender (for validation)
    ///   - accountBalance: Optional account balance in microCCD (for CCD transfer validation)
    ///   - tokenBalance: Optional token balance (for PLT transfer validation)
    /// - Returns: SignedSponsoredTransaction ready for submission
    /// - Throws: ValidationError or DeserializeError if validation/signing fails
    public static func createAndSign(
        headerHex: String,
        payloadHex: String,
        sponsorSignatureHex: String,
        signer: any Signer,
        expectedSender: AccountAddress,
        accountBalance: UInt64? = nil,
        tokenBalance: BigUInt? = nil
    ) throws -> SignedSponsoredTransaction {
        // Validate transaction
        let (header, _) = try SponsoredTransactionValidator.validate(
            headerHex: headerHex,
            payloadHex: payloadHex,
            expectedSender: expectedSender,
            accountBalance: accountBalance,
            tokenBalance: tokenBalance
        )

        // Create prepared transaction
        let preparedTransaction = try AccountTransaction.createSponsored(
            headerHex: headerHex,
            payloadHex: payloadHex
        )

        // Sign with sender's keys
        let senderSignatures = try signer.sign(sponsoredTransaction: preparedTransaction)

        // Decode sponsor signature (keep separate from sender signatures)
        let sponsorSignatures = try Signatures.decode(from: sponsorSignatureHex)

        // Create signed transaction with separate signatures
        return SignedSponsoredTransaction(
            transaction: preparedTransaction,
            senderSignatures: senderSignatures,
            sponsorSignatures: sponsorSignatures
        )
    }
}
