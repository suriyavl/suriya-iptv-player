import Foundation

struct EthereumNetwork: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let chainID: UInt64
    let rpcURL: URL
    let explorerURL: URL
    let isTestnet: Bool

    static let mainnet = EthereumNetwork(
        id: "mainnet",
        name: "Ethereum",
        chainID: 1,
        rpcURL: URL(string: "https://ethereum-rpc.publicnode.com")!,
        explorerURL: URL(string: "https://etherscan.io")!,
        isTestnet: false
    )

    static let sepolia = EthereumNetwork(
        id: "sepolia",
        name: "Sepolia Testnet",
        chainID: 11_155_111,
        rpcURL: URL(string: "https://ethereum-sepolia-rpc.publicnode.com")!,
        explorerURL: URL(string: "https://sepolia.etherscan.io")!,
        isTestnet: true
    )

    static let all: [EthereumNetwork] = [.mainnet, .sepolia]

    func transactionURL(_ hash: String) -> URL {
        explorerURL.appendingPathComponent("tx").appendingPathComponent(hash)
    }

    func addressURL(_ address: String) -> URL {
        explorerURL.appendingPathComponent("address").appendingPathComponent(address)
    }
}
