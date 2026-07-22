import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PlaylistStore

    var body: some View {
        if store.hasContent {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ChannelListView()
                .tabItem { Label("Channels", systemImage: "tv") }
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
