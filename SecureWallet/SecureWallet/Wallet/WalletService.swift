import Foundation
import WalletCore

enum WalletError: LocalizedError {
    case invalidMnemonic
    case invalidAddress
    case selfSend
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidMnemonic: return "That recovery phrase is not valid. Check every word and its order."
        case .invalidAddress: return "That is not a valid Ethereum address. Check the checksum (upper/lower case letters)."
        case .selfSend: return "The destination is this wallet's own address."
        case .signingFailed(let m): return "Signing failed: \(m)"
        }
    }
}

struct UnsignedTransfer {
    let network: EthereumNetwork
    let from: String
    let to: String
    let value: BigUInt
    let nonce: BigUInt
    let fee: FeeQuote

    var maxTotal: BigUInt { value + fee.maxNetworkFee }
}

/// All private-key operations. Keys are derived from the decrypted recovery
/// phrase only for the duration of a single call and are zeroed afterwards.
enum WalletService {
    static let wordCount = 24
    private static let coin = CoinType.ethereum

    /// Generates a 24-word (256-bit entropy) BIP39 phrase using the system CSPRNG
    /// inside WalletCore.
    static func generateMnemonic() -> String {
        HDWallet(strength: 256, passphrase: "")!.mnemonic
    }

    static func normalize(_ phrase: String) -> String {
        phrase.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func isValid(mnemonic: String) -> Bool {
        Mnemonic.isValid(mnemonic: normalize(mnemonic))
    }

    static func address(fromSeed seed: Data) throws -> String {
        guard let phrase = String(data: seed, encoding: .utf8),
              let wallet = HDWallet(mnemonic: phrase, passphrase: "") else {
            throw WalletError.invalidMnemonic
        }
        return wallet.getAddressForCoin(coin: coin)
    }

    /// Returns the EIP-55 checksummed form, or throws if the address is invalid.
    /// All-lowercase input is accepted, but mixed case must match the checksum.
    static func validatedAddress(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 42, trimmed.hasPrefix("0x"),
              let parsed = AnyAddress(string: trimmed, coin: coin) else {
            throw WalletError.invalidAddress
        }
        let body = trimmed.dropFirst(2)
        let isSingleCase = body == body.lowercased() || body == body.uppercased()
        guard isSingleCase || parsed.description == trimmed else { throw WalletError.invalidAddress }
        return parsed.description
    }

    static func sign(_ tx: UnsignedTransfer, seed: inout Data) throws -> String {
        guard let phrase = String(data: seed, encoding: .utf8),
              let wallet = HDWallet(mnemonic: phrase, passphrase: "") else {
            throw WalletError.invalidMnemonic
        }
        // Make sure the decrypted seed really belongs to the account we are sending from.
        guard wallet.getAddressForCoin(coin: coin).lowercased() == tx.from.lowercased() else {
            throw WalletError.signingFailed("wallet does not match the sending account")
        }
        var privateKey = wallet.getKeyForCoin(coin: coin).data
        defer { privateKey.secureZero() }

        var input = EthereumSigningInput.with {
            $0.chainID = BigUInt(tx.network.chainID).serialized
            $0.nonce = tx.nonce.serialized
            $0.txMode = .enveloped // EIP-1559
            $0.gasLimit = tx.fee.gasLimit.serialized
            $0.maxFeePerGas = tx.fee.maxFeePerGas.serialized
            $0.maxInclusionFeePerGas = tx.fee.maxPriorityFeePerGas.serialized
            $0.toAddress = tx.to
            $0.privateKey = privateKey
            $0.transaction = EthereumTransaction.with {
                $0.transfer = EthereumTransaction.Transfer.with { $0.amount = tx.value.serialized }
            }
        }
        let output: EthereumSigningOutput = AnySigner.sign(input: input, coin: coin)
        input.privateKey.secureZero()

        guard output.error == .ok, !output.encoded.isEmpty else {
            throw WalletError.signingFailed(output.errorMessage.isEmpty ? "\(output.error)" : output.errorMessage)
        }
        return output.encoded.hexString
    }
}
