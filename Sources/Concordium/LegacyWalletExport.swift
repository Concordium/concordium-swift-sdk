import CommonCrypto
import Foundation

public struct EncryptedExportJSON: Decodable {
    var cipherText: String // base64
    var metadata: Metadata

    public struct Metadata: Decodable {
        var encryptionMethod: String
        var initializationVector: String // base64
        var iterations: Int
        var keyDerivationMethod: String
        var salt: String // base64
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

public func decryptLegacyWalletExport(export: EncryptedExportJSON, password: Data) throws -> LegacyWalletExportJSON {
    let data = try decryptLegacyWalletExport(cipher: export.cipherText, metadata: export.metadata, password: password)
    guard String(data: data, encoding: .utf8) != nil else {
        // Decrypted payload is not valid UTF-8.
        throw DecryptExportError.invalidPasswordOrCorrupted
    }
    return try JSONDecoder().decode(LegacyWalletExportJSON.self, from: data)
}

func decryptLegacyWalletExport(cipher: String, metadata: EncryptedExportJSON.Metadata, password: Data) throws -> Data {
    guard metadata.keyDerivationMethod == "PBKDF2WithHmacSHA256" else {
        throw DecryptExportError.unsupportedKeyDerivationMethod(metadata.keyDerivationMethod)
    }
    guard metadata.encryptionMethod == "AES-256" else {
        throw DecryptExportError.unsupportedEncryptionMethod(metadata.encryptionMethod)
    }
    return try decryptLegacyWalletExport(
        cipher: Data(base64Encoded: cipher) ?! DecryptExportError.invalidCipher(cipher),
        salt: Data(base64Encoded: metadata.salt) ?! DecryptExportError.invalidSalt(metadata.salt),
        iterations: metadata.iterations,
        iv: Data(base64Encoded: metadata.initializationVector) ?! DecryptExportError.invalidInitializationVector(metadata.initializationVector),
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
                    passwordBytes.baseAddress!,
                    passwordBytes.count,
                    saltBytes.baseAddress!,
                    saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    resBytes,
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
