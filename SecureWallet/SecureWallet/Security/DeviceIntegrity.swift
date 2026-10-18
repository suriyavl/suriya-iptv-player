import Foundation
import LocalAuthentication

/// Environment checks performed before any secret is created or used.
enum DeviceIntegrity {
    /// A device passcode is required: without it the Keychain item and the
    /// Secure Enclave key cannot be created with our access policy.
    static var isPasscodeSet: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var isBiometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static func requirePasscode() throws {
        guard isPasscodeSet else { throw VaultError.passcodeNotSet }
    }

    /// Heuristic jailbreak detection. It can be bypassed by a determined attacker,
    /// but it warns ordinary users that their device no longer protects app secrets.
    static var isLikelyJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/var/jb",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
        ]
        if suspiciousPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return true
        }
        // A sandboxed app must not be able to write outside its container.
        let probe = "/private/jb_probe_\(UUID().uuidString)"
        if (try? "x".write(toFile: probe, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: probe)
            return true
        }
        return false
        #endif
    }

    static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
