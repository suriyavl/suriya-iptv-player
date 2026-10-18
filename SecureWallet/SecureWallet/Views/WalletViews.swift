import CoreImage.CIFilterBuiltins
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        if store.network.isTestnet {
                            Text("TESTNET").font(.caption.bold()).foregroundStyle(.orange)
                        }
                        Text(store.balance.map { "\(Ether.format($0)) ETH" } ?? "—")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .privacySensitive()
                        Text(store.network.name).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)

                    HStack {
                        Button { showReceive = true } label: { Label("Receive", systemImage: "arrow.down.circle.fill") }
                        Spacer()
                        Button { showSend = true } label: { Label("Send", systemImage: "arrow.up.circle.fill") }
                            .disabled(store.balance == nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.headline)
                }
                if let address = store.address {
                    Section("Account") {
                        Text(address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                        Link("View on explorer", destination: store.network.addressURL(address))
                    }
                }
                if let error = store.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .refreshable { await store.refresh() }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.lock() } label: { Image(systemName: "lock") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showReceive) { ReceiveView() }
            .sheet(isPresented: $showSend) { SendView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

struct ReceiveView: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let address = store.address {
                    if let image = qrCode(for: address) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 240, height: 240)
                    }
                    Text(address).font(.system(.callout, design: .monospaced)).multilineTextAlignment(.center)
                    Text("Only send ETH on \(store.network.name) to this address.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(copied ? "Copied (clears in 60 s)" : "Copy address") {
                        SecureClipboard.copy(address)
                        copied = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Receive")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func qrCode(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct SendView: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var amount = ""
    @State private var prepared: UnsignedTransfer?
    @State private var txHash: String?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                if let txHash {
                    Section("Sent") {
                        Text(txHash).font(.system(.footnote, design: .monospaced))
                        Link("View on explorer", destination: store.network.transactionURL(txHash))
                    }
                } else if let tx = prepared {
                    ConfirmSection(tx: tx)
                    Section {
                        Button {
                            run { txHash = try await store.signAndSend(tx) }
                        } label: {
                            Label("Confirm with Face ID", systemImage: "faceid")
                        }
                        Button("Edit", role: .cancel) { prepared = nil }
                    }
                } else {
                    Section("Recipient") {
                        TextField("0x…", text: $recipient)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section {
                        TextField("0.0", text: $amount).keyboardType(.decimalPad)
                    } header: {
                        Text("Amount (ETH)")
                    } footer: {
                        if let balance = store.balance { Text("Available: \(Ether.format(balance, maxFractionDigits: 18)) ETH") }
                    }
                    Button("Review") {
                        run { prepared = try await store.prepareTransfer(to: recipient, amount: amount) }
                    }
                    .disabled(recipient.isEmpty || amount.isEmpty)
                }
                if busy { ProgressView() }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .disabled(busy)
            .navigationTitle("Send ETH")
            .toolbar { Button(txHash == nil ? "Cancel" : "Done") { dismiss() } }
        }
        // Fee quotes and nonces go stale; never sign an old review.
        .onChange(of: recipient) { prepared = nil }
        .onChange(of: amount) { prepared = nil }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do { try await work() } catch { self.error = error.localizedDescription }
        }
    }
}

/// Shows exactly what will be signed. The address is broken into groups so
/// address-poisoning look-alikes (same first/last characters) are easier to spot.
struct ConfirmSection: View {
    let tx: UnsignedTransfer

    var body: some View {
        Section("Review carefully") {
            LabeledContent("Network", value: tx.network.name)
            VStack(alignment: .leading, spacing: 4) {
                Text("To").foregroundStyle(.secondary)
                Text(grouped(tx.to)).font(.system(.callout, design: .monospaced))
            }
            LabeledContent("Amount", value: "\(Ether.format(tx.value, maxFractionDigits: 18)) ETH")
            LabeledContent("Max network fee", value: "\(Ether.format(tx.fee.maxNetworkFee, maxFractionDigits: 8)) ETH")
            LabeledContent("Max total", value: "\(Ether.format(tx.maxTotal, maxFractionDigits: 8)) ETH").bold()
        }
        Section {
            Text("Check the full address against the one you were given, not only the first and last characters. Transactions cannot be reversed.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func grouped(_ address: String) -> String {
        let body = Array(address.dropFirst(2))
        let groups = stride(from: 0, to: body.count, by: 4).map { String(body[$0..<min($0 + 4, body.count)]) }
        return "0x " + groups.joined(separator: " ")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @State private var revealedPhrase: [String]?
    @State private var confirmWipe = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Network") {
                    Picker("Network", selection: $store.network) {
                        ForEach(EthereumNetwork.all) { Text($0.name).tag($0) }
                    }
                }
                Section {
                    if let words = revealedPhrase {
                        SensitiveContent { PhraseGrid(words: words) }
                        Button("Hide") { revealedPhrase = nil }
                    } else {
                        Button("Show recovery phrase") {
                            Task {
                                do {
                                    revealedPhrase = try await store.revealMnemonic().split(separator: " ").map(String.init)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Requires Face ID or Touch ID every time.")
                }
                Section {
                    Text("Auto-lock after \(Int(store.autoLockInterval)) seconds in the background. Every transaction needs Face ID or Touch ID. If biometrics are re-enrolled, the wallet key is destroyed and you must restore from your recovery phrase.")
                        .font(.footnote)
                }
                Section {
                    Button("Delete wallet from this device", role: .destructive) { confirmWipe = true }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .onDisappear { revealedPhrase = nil }
            .confirmationDialog("Delete wallet?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { if await store.wipe() { dismiss() } }
                }
            } message: {
                Text("Without your recovery phrase, your funds will be lost forever.")
            }
        }
    }
}
