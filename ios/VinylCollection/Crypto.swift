import Foundation
import CommonCrypto
import CryptoKit

enum CryptoError: LocalizedError {
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidEnvelope

    var errorDescription: String? {
        switch self {
        case .keyDerivationFailed: return "Failed to derive encryption key"
        case .encryptionFailed:    return "Encryption failed"
        case .decryptionFailed:    return "Decryption failed — wrong password?"
        case .invalidEnvelope:     return "Invalid encrypted envelope"
        }
    }
}

enum CryptoService {

    // PBKDF2-SHA256 · salt = "vinyl-collection-salt" · 100,000 iterations · 32-byte key
    static func deriveKey(from password: String) throws -> Data {
        let salt     = Array("vinyl-collection-salt".utf8)
        let passArr  = Array(password.utf8)
        var derived  = [UInt8](repeating: 0, count: 32)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passArr,  passArr.count,
            salt,     salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            100_000,
            &derived, 32
        )
        guard status == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return Data(derived)
    }

    // Token = lowercase hex of SHA-256(raw key bytes)
    static func keyToToken(_ key: Data) -> String {
        SHA256.hash(data: key).map { String(format: "%02x", $0) }.joined()
    }

    // Encrypt any JSON-serialisable object → {"iv": "<b64>", "data": "<b64>"}
    static func encrypt(key: Data, object: Any) throws -> [String: String] {
        let plain   = try JSONSerialization.data(withJSONObject: object)
        let ivBytes = (0..<16).map { _ in UInt8.random(in: 0...255) }

        let outSize = plain.count + kCCBlockSizeAES128
        var cipher  = [UInt8](repeating: 0, count: outSize)
        var nOut    = 0

        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            Array(key), kCCKeySizeAES256,
            ivBytes,
            Array(plain), plain.count,
            &cipher, outSize,
            &nOut
        )
        guard status == kCCSuccess else { throw CryptoError.encryptionFailed }

        return [
            "iv":   Data(ivBytes).base64EncodedString(),
            "data": Data(cipher.prefix(nOut)).base64EncodedString()
        ]
    }

    // Decrypt {"iv": ..., "data": ...} → JSON object
    static func decrypt(key: Data, envelope: [String: Any]) throws -> Any {
        guard let ivB64  = envelope["iv"]   as? String,
              let datB64 = envelope["data"] as? String,
              let iv     = Data(base64Encoded: ivB64),
              let cipher = Data(base64Encoded: datB64)
        else { throw CryptoError.invalidEnvelope }

        let outSize = cipher.count + kCCBlockSizeAES128
        var plain   = [UInt8](repeating: 0, count: outSize)
        var nOut    = 0

        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            Array(key), kCCKeySizeAES256,
            Array(iv),
            Array(cipher), cipher.count,
            &plain, outSize,
            &nOut
        )
        guard status == kCCSuccess else { throw CryptoError.decryptionFailed }
        return try JSONSerialization.jsonObject(with: Data(plain.prefix(nOut)))
    }
}
