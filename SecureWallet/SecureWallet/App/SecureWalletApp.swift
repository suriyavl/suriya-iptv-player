import SwiftUI
import UIKit

@main
struct SecureWalletApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = WalletStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .overlay {
                    // Hides balances and phrases from the app switcher snapshot.
                    if scenePhase != .active { PrivacyShieldView() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    store.scenePhaseChanged(newPhase)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Third-party keyboards can log keystrokes, including a typed recovery phrase.
    func application(
        _ application: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        extensionPointIdentifier != .keyboard
    }
}
