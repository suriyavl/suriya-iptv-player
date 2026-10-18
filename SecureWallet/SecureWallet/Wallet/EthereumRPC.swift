import Foundation

enum RPCError: LocalizedError {
    case insecureEndpoint
    case http(Int)
    case server(String)
    case malformed(String)
    case chainMismatch(expected: UInt64, got: UInt64)

    var errorDescription: String? {
        switch self {
        case .insecureEndpoint: return "Only HTTPS RPC endpoints are allowed."
        case .http(let code): return "The network returned HTTP \(code)."
        case .server(let message): return message
        case .malformed(let field): return "Unexpected response from the network (\(field))."
        case .chainMismatch(let e, let g): return "The RPC node reports chain \(g), expected \(e). Refusing to continue."
        }
    }
}

struct FeeQuote {
    let gasLimit: BigUInt
    let maxFeePerGas: BigUInt
    let maxPriorityFeePerGas: BigUInt

    var maxNetworkFee: BigUInt { gasLimit * maxFeePerGas }
}

/// Small JSON-RPC client. Uses an ephemeral session (no cookies, no disk cache)
/// and refuses anything other than HTTPS.
actor EthereumRPC {
    nonisolated let network: EthereumNetwork
    private let session: URLSession
    private var nextID = 1

    init(network: EthereumNetwork) {
        self.network = network
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        session = URLSession(configuration: config)
    }

    // MARK: - Calls

    func balance(of address: String) async throws -> BigUInt {
        try await quantity("eth_getBalance", [address, "latest"])
    }

    func pendingNonce(of address: String) async throws -> BigUInt {
        try await quantity("eth_getTransactionCount", [address, "pending"])
    }

    /// Ensures the node is really serving the chain we are about to sign for.
    func verifyChainID() async throws {
        let id = try await quantity("eth_chainId", [])
        guard id == BigUInt(network.chainID) else {
            throw RPCError.chainMismatch(expected: network.chainID, got: UInt64(id.description) ?? 0)
        }
    }

    func feeQuote(from: String, to: String, value: BigUInt) async throws -> FeeQuote {
        let txCall: [String: String] = ["from": from, "to": to, "value": "0x" + value.hexString]
        async let gasEstimate = quantity("eth_estimateGas", [txCall])
        async let priority = quantity("eth_maxPriorityFeePerGas", [])
        async let block = call("eth_getBlockByNumber", ["latest", false])

        let blockObject = try await block as? [String: Any]
        guard let baseHex = blockObject?["baseFeePerGas"] as? String, let baseFee = BigUInt(hex: baseHex) else {
            throw RPCError.malformed("baseFeePerGas")
        }
        let tip = try await priority
        // Headroom: survives the base fee doubling across several blocks.
        let maxFee = baseFee * BigUInt(2) + tip
        // 20% safety margin on the estimate; a plain transfer is exactly 21000.
        let estimate = try await gasEstimate
        let gasLimit = estimate == BigUInt(21_000) ? estimate : (estimate * BigUInt(6)).divided(bySmall: 5).quotient
        return FeeQuote(gasLimit: gasLimit, maxFeePerGas: maxFee, maxPriorityFeePerGas: tip)
    }

    func sendRawTransaction(_ hex: String) async throws -> String {
        guard let hash = try await call("eth_sendRawTransaction", ["0x" + hex]) as? String else {
            throw RPCError.malformed("transaction hash")
        }
        return hash
    }

    // MARK: - Transport

    private func quantity(_ method: String, _ params: [Any]) async throws -> BigUInt {
        guard let hex = try await call(method, params) as? String, let value = BigUInt(hex: hex) else {
            throw RPCError.malformed(method)
        }
        return value
    }

    private func call(_ method: String, _ params: [Any]) async throws -> Any {
        guard network.rpcURL.scheme?.lowercased() == "https" else { throw RPCError.insecureEndpoint }

        var request = URLRequest(url: network.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let id = nextID
        nextID += 1
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": id, "method": method, "params": params,
        ])

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RPCError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RPCError.malformed(method)
        }
        if let error = json["error"] as? [String: Any] {
            throw RPCError.server(error["message"] as? String ?? "RPC error")
        }
        guard let result = json["result"] else { throw RPCError.malformed(method) }
        return result
    }
}
