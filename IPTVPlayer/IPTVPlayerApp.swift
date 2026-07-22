import SwiftUI

@main
struct IPTVPlayerApp: App {
    @StateObject private var store = PlaylistStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
