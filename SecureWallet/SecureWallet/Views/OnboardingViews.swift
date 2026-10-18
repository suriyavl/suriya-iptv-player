import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        VStack(spacing: 0) {
            IntegrityBanner()
            switch store.phase {
            case .onboarding: WelcomeView()
            case .locked: LockView()
            case .unlocked: HomeView()
            }
        }
    }
}

struct LockView: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 56)).foregroundStyle(.tint)
            Text("Wallet locked").font(.title2.bold())
            Button("Unlock") { Task { await store.unlock() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
        .task { await store.unlock() }
    }
}

struct WelcomeView: View {
    @State private var path: [Route] = []
    private var passcodeSet: Bool { DeviceIntegrity.isPasscodeSet }
    private var biometrySet: Bool { DeviceIntegrity.isBiometryAvailable }

    enum Route: Hashable { case create, verify([String]), importWallet }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "lock.shield.fill").font(.system(size: 72)).foregroundStyle(.tint)
                Text("Secure Wallet").font(.largeTitle.bold())
                Text("Self-custody Ethereum wallet. Your keys are encrypted by the Secure Enclave and never leave this device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                if !passcodeSet || !biometrySet {
                    Label(
                        passcodeSet ? "Enroll Face ID or Touch ID in Settings to continue." : "Set a device passcode and Face ID / Touch ID in Settings to continue.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
                Button("Create new wallet") { path.append(.create) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Import recovery phrase") { path.append(.importWallet) }
                    .controlSize(.large)
            }
            .disabled(!passcodeSet || !biometrySet)
            .padding()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .create: CreateWalletView { words in path.append(.verify(words)) }
                case .verify(let words): VerifyPhraseView(words: words)
                case .importWallet: ImportWalletView()
                }
            }
        }
    }
}

struct CreateWalletView: View {
    let onContinue: ([String]) -> Void
    @State private var words: [String] = WalletService.generateMnemonic().split(separator: " ").map(String.init)
    @State private var revealed = false
    @State private var acknowledged = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Write down these \(words.count) words on paper, in order. Anyone with them can take your funds. Never type them into a website or share them with \"support\".")
                    .font(.callout)
                SensitiveContent {
                    ZStack {
                        PhraseGrid(words: words).blur(radius: revealed ? 0 : 12)
                        if !revealed {
                            Button("Tap to reveal") { revealed = true }.buttonStyle(.bordered)
                        }
                    }
                }
                Toggle("I wrote it down on paper and stored it safely offline.", isOn: $acknowledged)
                Button("Continue") { onContinue(words) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!acknowledged || !revealed)
            }
            .padding()
        }
        .navigationTitle("Recovery phrase")
        .onDisappear { revealed = false }
    }
}

struct PhraseGrid: View {
    let words: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                    Text(word).bold()
                    Spacer(minLength: 0)
                }
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        // Long-press copy menus would put the phrase on the clipboard.
        .textSelection(.disabled)
    }
}

/// Forces the user to prove they recorded the phrase before any funds can arrive.
struct VerifyPhraseView: View {
    @EnvironmentObject private var store: WalletStore
    let words: [String]
    @State private var challenge: [Int] = []
    @State private var answers: [Int: String] = [:]
    @State private var error: String?

    var body: some View {
        Form {
            Section("Enter the requested words from your paper copy") {
                ForEach(challenge, id: \.self) { index in
                    TextField("Word #\(index + 1)", text: Binding(
                        get: { answers[index, default: ""] },
                        set: { answers[index] = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Create wallet") { verify() }
                .disabled(answers.values.filter { !$0.isEmpty }.count < challenge.count)
        }
        .navigationTitle("Verify backup")
        .onAppear {
            if challenge.isEmpty {
                challenge = Array((0..<words.count).shuffled().prefix(4)).sorted()
            }
        }
    }

    private func verify() {
        let correct = challenge.allSatisfy {
            answers[$0, default: ""].trimmingCharacters(in: .whitespaces).lowercased() == words[$0]
        }
        guard correct else {
            error = "One or more words are wrong. Go back and check your paper copy."
            answers = [:]
            return
        }
        do {
            try store.saveWallet(mnemonic: words.joined(separator: " "))
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ImportWalletView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var phrase = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextEditor(text: $phrase)
                    .frame(minHeight: 140)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .privacySensitive()
            } header: {
                Text("Recovery phrase (12 or 24 words)")
            } footer: {
                Text("Type it in. Pasting puts the phrase on the clipboard, where other apps can read it.")
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button("Import") {
                do {
                    try store.saveWallet(mnemonic: phrase)
                    phrase = ""
                } catch {
                    self.error = error.localizedDescription
                }
            }
            .disabled(phrase.split(whereSeparator: \.isWhitespace).count < 12)
        }
        .navigationTitle("Import wallet")
        .onDisappear { phrase = "" }
    }
}
