import Foundation
import LocalAuthentication
import Security

enum VaultError: LocalizedError {
    case passcodeNotSet
    case keyGenerationFailed(String)
    case keyNotFound
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keychain(OSStatus)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .passcodeNotSet: return "Set a device passcode in Settings before creating a wallet."
        case .keyGenerationFailed(let m): return "Could not create the Secure Enclave key: \(m)"
        case .keyNotFound: return "The wallet key is missing or was invalidated (for example, Face ID was re-enrolled). Restore from your recovery phrase."
        case .encryptionFailed(let m): return "Encryption failed: \(m)"
        case .decryptionFailed(let m): return "Decryption failed: \(m)"
        case .keychain(let s): return "Keychain error \(s)."
        case .userCancelled: return "Authentication was cancelled."
        }
    }
}

/// Stores the recovery phrase encrypted under a P-256 key that lives inside the
/// Secure Enclave and can never be exported.
///
/// - The Enclave key requires the *current* biometric set to decrypt. Adding a new
///   face or fingerprint invalidates it, so someone who learns the device passcode
///   cannot enroll their own face and drain the wallet.
/// - The ciphertext lives in the Keychain as `WhenPasscodeSetThisDeviceOnly`:
///   never synced to iCloud, never restored to another device from a backup, and
///   deleted automatically if the device passcode is removed.
/// - Encrypting needs only the public key, so no prompt is shown when a wallet is
///   created; every decrypt (sign or reveal) requires Face ID / Touch ID.
final class SecureEnclaveVault {
    static let shared = SecureEnclaveVault()

    private let keyTag = Data("com.suriya.securewallet.enclave.key".utf8)
    private let service = "com.suriya.securewallet.vault"
    private let secretAccount = "encrypted-seed"
    private let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM

    private init() {}

    var hasWallet: Bool {
        (try? loadCiphertext()) != nil
    }

    // MARK: - Public API

    func store(secret: Data) throws {
        try DeviceIntegrity.requirePasscode()
        try deleteAll()
        let privateKey = try createEnclaveKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw VaultError.keyGenerationFailed("no public key")
        }
        var error: Unmanaged<CFError>?
        guard let ciphertext = SecKeyCreateEncryptedData(publicKey, algorithm, secret as CFData, &error) as Data? else {
            throw VaultError.encryptionFailed(error.map { "\($0.takeRetainedValue())" } ?? "unknown")
        }
        try saveCiphertext(ciphertext)
    }

    /// Decrypts the secret. Triggers a biometric prompt with `reason`.
    /// The caller must zero the returned buffer as soon as it is done with it.
    func withSecret<T>(reason: String, _ body: (inout Data) throws -> T) throws -> T {
        let context = LAContext()
        context.localizedReason = reason
        context.localizedFallbackTitle = "" // biometrics only, no passcode fallback for signing
        let privateKey = try loadEnclaveKey(context: context)
        let ciphertext = try loadCiphertext()

        var error: Unmanaged<CFError>?
        guard var plaintext = SecKeyCreateDecryptedData(privateKey, algorithm, ciphertext as CFData, &error) as Data? else {
            let cfError = error?.takeRetainedValue()
            if let cfError, CFErrorGetCode(cfError) == LAError.userCancel.rawValue || CFErrorGetCode(cfError) == errSecUserCanceled {
                throw VaultError.userCancelled
            }
            throw VaultError.decryptionFailed(cfError.map { "\($0)" } ?? "unknown")
        }
        defer { plaintext.secureZero() }
        return try body(&plaintext)
    }

    func deleteAll() throws {
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
        ]
        let keyStatus = SecItemDelete(keyQuery as CFDictionary)
        guard keyStatus == errSecSuccess || keyStatus == errSecItemNotFound else { throw VaultError.keychain(keyStatus) }

        let itemQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let itemStatus = SecItemDelete(itemQuery as CFDictionary)
        guard itemStatus == errSecSuccess || itemStatus == errSecItemNotFound else { throw VaultError.keychain(itemStatus) }
    }

    // MARK: - Enclave key

    private func createEnclaveKey() throws -> SecKey {
        #if targetEnvironment(simulator)
        // No Secure Enclave in the simulator: software key, development only.
        let flags: SecAccessControlCreateFlags = [.userPresence]
        #else
        let flags: SecAccessControlCreateFlags = [.privateKeyUsage, .biometryCurrentSet]
        #endif
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            flags,
            &error
        ) else {
            throw VaultError.keyGenerationFailed(error.map { "\($0.takeRetainedValue())" } ?? "access control")
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: access,
            ] as [String: Any],
        ]
        #if !targetEnvironment(simulator)
        attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        #endif

        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw VaultError.keyGenerationFailed(error.map { "\($0.takeRetainedValue())" } ?? "unknown")
        }
        return key
    }

    private func loadEnclaveKey(context: LAContext) throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else { throw VaultError.keyNotFound }
        return item as! SecKey // swiftlint:disable:this force_cast
    }

    // MARK: - Ciphertext storage

    private func saveCiphertext(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: secretAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
    }

    private func loadCiphertext() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: secretAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { throw VaultError.keyNotFound }
        return data
    }
}

extension Data {
    /// Overwrites the buffer with zeros so the secret does not linger in memory.
    mutating func secureZero() {
        guard !isEmpty else { return }
        let count = self.count
        withUnsafeMutableBytes { raw in
            if let base = raw.baseAddress {
                _ = memset_s(base, count, 0, count)
            }
        }
    }
}
