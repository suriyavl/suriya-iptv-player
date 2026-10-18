import Foundation
import LocalAuthentication

/// Gate for opening the app UI. This only unlocks *viewing*; signing and
/// revealing the recovery phrase always require a fresh Secure Enclave
/// biometric check in `SecureEnclaveVault`.
enum AppLock {
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
