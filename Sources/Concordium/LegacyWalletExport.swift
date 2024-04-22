import CommonCrypto
import Foundation

public struct LegacyWalletEncryptedExportJSON: Decodable {
    public var cipherText: Data // base64
    var metadata: Metadata

    enum CodingKeys: CodingKey {
        case cipherText
        case metadata
    }

    public struct Metadata: Decodable {
        var encryptionMethod: String
        var initializationVector: Data // base64
        var iterations: Int
        var keyDerivationMethod: String
        var salt: Data // base64
    }
}

public struct LegacyWalletExportJSON: Decodable {
    public var environment: String
    public var value: Value

    enum CodingKeys: CodingKey {
        case v
        case type
        case environment
        case value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "concordium-mobile-wallet-data" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "unsupported export type '\(type)'")
        }
        let version = try container.decode(Int.self, forKey: .v)
        guard version == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .v, in: container, debugDescription: "unsupported export version '\(version)'")
        }
        environment = try container.decode(String.self, forKey: .environment)
        value = try container.decode(Value.self, forKey: .value)
    }

    public func toSDKType() throws -> [Concordium.Account] {
        try value.identities.flatMap {
            try $0.accounts.map { account in
                try Concordium.Account(
                    address: AccountAddress(base58Check: account.address),
                    keys: account.accountKeys.toSDKType()
                )
            }
        }
    }

    public struct Value: Decodable {
        public var identities: [Identity]
    }

    public struct Identity: Decodable {
        public var accounts: [Account]
    }

    public struct Account: Decodable {
        public var address: String
        public var accountKeys: AccountKeysJSON
    }
}

enum DecryptExportError: Error {
    case keyGenerationFailed(status: Int)
    case decryptionFailed(status: CCCryptorStatus)
    case unsupportedEncryptionMethod(String)
    case unsupportedKeyDerivationMethod(String)
    case unsupportedKeyLength
    case unsupportedInputVectorLength
    case invalidCipher(String)
    case invalidSalt(String)
    case invalidInitializationVector(String)
    case invalidPasswordOrCorrupted
}

public func decryptLegacyWalletExport(export: LegacyWalletEncryptedExportJSON, password: Data) throws -> LegacyWalletExportJSON {
    let data = try decryptLegacyWalletExport(cipher: export.cipherText, metadata: export.metadata, password: password)
    guard String(data: data, encoding: .utf8) != nil else {
        // Decrypted payload is not valid UTF-8.
        throw DecryptExportError.invalidPasswordOrCorrupted
    }
    return try JSONDecoder().decode(LegacyWalletExportJSON.self, from: data)
}

func decryptLegacyWalletExport(cipher: Data, metadata: LegacyWalletEncryptedExportJSON.Metadata, password: Data) throws -> Data {
    guard metadata.keyDerivationMethod == "PBKDF2WithHmacSHA256" else {
        throw DecryptExportError.unsupportedKeyDerivationMethod(metadata.keyDerivationMethod)
    }
    guard metadata.encryptionMethod == "AES-256" else {
        throw DecryptExportError.unsupportedEncryptionMethod(metadata.encryptionMethod)
    }
    return try decryptLegacyWalletExport(
        cipher: cipher,
        salt: metadata.salt,
        iterations: metadata.iterations,
        iv: metadata.initializationVector,
        password: password
    )
}

func decryptLegacyWalletExport(cipher: Data, salt: Data, iterations: Int, iv: Data, password: Data) throws -> Data {
    try decryptAES256(
        key: deriveKeyAES256(password: password, salt: salt, rounds: iterations),
        iv: iv,
        cipher
    )
}

func deriveKeyAES256(password: Data, salt: Data, rounds: Int) throws -> Data {
    var res = Data(repeating: 0, count: kCCKeySizeAES256)
    let status = password.withUnsafeBytes { passwordBytes in
        salt.withUnsafeBytes { saltBytes in
            res.withUnsafeMutableBytes { resBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress,
                    passwordBytes.count,
                    saltBytes.baseAddress,
                    saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    resBytes.baseAddress,
                    kCCKeySizeAES256
                )
            }
        }
    }
    guard status == 0 else {
        throw DecryptExportError.keyGenerationFailed(status: Int(status))
    }
    return res
}

func decryptAES256(key: Data, iv: Data, _ input: Data) throws -> Data {
    guard key.count == kCCKeySizeAES256 else {
        throw DecryptExportError.unsupportedKeyLength
    }
    guard iv.count == kCCBlockSizeAES128 else {
        throw DecryptExportError.unsupportedInputVectorLength
    }
    var data = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
    var count = 0
    let status = CCCrypt(
        CCOperation(kCCDecrypt),
        CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionPKCS7Padding),
        [UInt8](key),
        key.count,
        [UInt8](iv),
        [UInt8](input),
        input.count,
        &data,
        data.count,
        &count
    )
    guard status == kCCSuccess else {
        throw DecryptExportError.decryptionFailed(status: status)
    }
    return Data(bytes: data, count: count)
}
