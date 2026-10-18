import Foundation
import SwiftUI

@MainActor
final class WalletStore: ObservableObject {
    enum Phase { case onboarding, locked, unlocked }

    @Published private(set) var phase: Phase = .onboarding
    @Published private(set) var address: String?
    @Published private(set) var balance: BigUInt?
    @Published private(set) var isRefreshing = false
    @Published var lastError: String?
    @Published var network: EthereumNetwork {
        didSet {
            defaults.set(network.id, forKey: Keys.network)
            balance = nil
            Task { await refresh() }
        }
    }

    /// Seconds in the background before the app locks again.
    let autoLockInterval: TimeInterval = 30

    private let vault = SecureEnclaveVault.shared
    private let defaults = UserDefaults.standard
    private var backgroundedAt: Date?

    private enum Keys {
        static let installed = "installMarker"
        static let address = "accountAddress"
        static let network = "networkID"
    }

    init() {
        let savedNetwork = defaults.string(forKey: Keys.network)
        network = EthereumNetwork.all.first { $0.id == savedNetwork } ?? .mainnet

        // Keychain items survive app deletion. A fresh install must never silently
        // pick up a previous owner's encrypted wallet.
        if !defaults.bool(forKey: Keys.installed) {
            try? vault.deleteAll()
            defaults.removeObject(forKey: Keys.address)
            defaults.set(true, forKey: Keys.installed)
        }

        address = defaults.string(forKey: Keys.address)
        phase = (vault.hasWallet && address != nil) ? .locked : .onboarding
    }

    var rpc: EthereumRPC { EthereumRPC(network: network) }

    // MARK: - Lifecycle

    func unlock() async {
        guard phase == .locked else { return }
        if await AppLock.authenticate(reason: "Unlock your wallet") {
            phase = .unlocked
            await refresh()
        }
    }

    func lock() {
        guard phase == .unlocked else { return }
        phase = .locked
        balance = nil
    }

    func scenePhaseChanged(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .background:
            backgroundedAt = Date()
        case .active:
            if let since = backgroundedAt, Date().timeIntervalSince(since) >= autoLockInterval {
                lock()
            }
            backgroundedAt = nil
        default:
            break
        }
    }

    // MARK: - Wallet creation

    /// Encrypts the phrase into the Secure Enclave vault. No prompt is shown here,
    /// but the device must have a passcode.
    func saveWallet(mnemonic: String) throws {
        let phrase = WalletService.normalize(mnemonic)
        guard WalletService.isValid(mnemonic: phrase) else { throw WalletError.invalidMnemonic }
        var seed = Data(phrase.utf8)
        defer { seed.secureZero() }
        let derived = try WalletService.address(fromSeed: seed)
        try vault.store(secret: seed)
        defaults.set(derived, forKey: Keys.address)
        address = derived
        phase = .unlocked
        Task { await refresh() }
    }

    /// Requires device-owner authentication so a thief holding an unlocked phone
    /// cannot destroy the wallet.
    func wipe() async -> Bool {
        guard await AppLock.authenticate(reason: "Delete the wallet from this device") else { return false }
        try? vault.deleteAll()
        defaults.removeObject(forKey: Keys.address)
        address = nil
        balance = nil
        phase = .onboarding
        return true
    }

    /// Reveals the phrase after a fresh biometric check. The caller shows it and
    /// discards it immediately.
    func revealMnemonic() async throws -> String {
        let vault = self.vault
        // Biometric Keychain operations block the calling thread; keep them off the main actor.
        return try await Task.detached {
            try vault.withSecret(reason: "Reveal your recovery phrase") { seed in
                String(decoding: seed, as: UTF8.self)
            }
        }.value
    }

    // MARK: - Chain data

    func refresh() async {
        guard let address, phase == .unlocked else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            balance = try await rpc.balance(of: address)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func prepareTransfer(to rawAddress: String, amount rawAmount: String) async throws -> UnsignedTransfer {
        guard let from = address else { throw WalletError.invalidMnemonic }
        let to = try WalletService.validatedAddress(rawAddress)
        guard to.lowercased() != from.lowercased() else { throw WalletError.selfSend }
        guard let value = Ether.parse(rawAmount), !value.isZero else {
            throw TransferError.invalidAmount
        }

        let rpc = self.rpc
        try await rpc.verifyChainID()
        async let fee = rpc.feeQuote(from: from, to: to, value: value)
        async let nonce = rpc.pendingNonce(of: from)
        async let balance = rpc.balance(of: from)

        let tx = try await UnsignedTransfer(network: network, from: from, to: to, value: value, nonce: nonce, fee: fee)
        guard try await tx.maxTotal <= balance else { throw TransferError.insufficientFunds }
        return tx
    }

    /// Requires Face ID / Touch ID for every signature, then broadcasts.
    func signAndSend(_ tx: UnsignedTransfer) async throws -> String {
        let reason = "Send \(Ether.format(tx.value)) ETH to \(tx.to.prefix(6))…\(tx.to.suffix(4))"
        let vault = self.vault
        let raw = try await Task.detached {
            try vault.withSecret(reason: reason) { seed in
                try WalletService.sign(tx, seed: &seed)
            }
        }.value
        let hash = try await EthereumRPC(network: tx.network).sendRawTransaction(raw)
        Task { await refresh() }
        return hash
    }
}

enum TransferError: LocalizedError {
    case invalidAmount
    case insufficientFunds

    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Enter an amount greater than zero, with at most 18 decimal places."
        case .insufficientFunds: return "Not enough ETH to cover the amount plus the maximum network fee."
        }
    }
}
