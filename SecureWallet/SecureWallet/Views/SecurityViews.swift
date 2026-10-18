import SwiftUI
import UIKit

struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
        }
        .ignoresSafeArea()
    }
}

/// Tracks whether the screen is being recorded, mirrored, or AirPlayed.
@MainActor
final class ScreenCaptureMonitor: ObservableObject {
    @Published private(set) var isCaptured = false
    @Published var screenshotTaken = false
    private var observers: [NSObjectProtocol] = []

    init() {
        update()
        observers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.update() } })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.screenshotTaken = true } })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    private func update() {
        isCaptured = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.isCaptured }
            .contains(true)
    }
}

/// Wraps content that must never appear in a recording or screenshot.
struct SensitiveContent<Content: View>: View {
    @StateObject private var monitor = ScreenCaptureMonitor()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if monitor.isCaptured {
                ContentUnavailableView(
                    "Screen recording detected",
                    systemImage: "eye.slash",
                    description: Text("Your recovery phrase is hidden while the screen is being recorded or mirrored.")
                )
            } else {
                content().privacySensitive()
            }
        }
        .alert("Screenshot detected", isPresented: $monitor.screenshotTaken) {
            Button("I understand", role: .cancel) {}
        } message: {
            Text("Screenshots are synced to iCloud Photos and readable by other apps. Delete it now and write your phrase on paper instead.")
        }
    }
}

struct IntegrityBanner: View {
    var body: some View {
        if DeviceIntegrity.isLikelyJailbroken || DeviceIntegrity.isDebuggerAttached {
            Label("This device appears to be jailbroken or under a debugger. Your wallet cannot be protected on it.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(.red)
        }
    }
}
