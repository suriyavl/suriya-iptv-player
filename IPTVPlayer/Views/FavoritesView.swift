import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var store: PlaylistStore

    private var favoriteChannels: [Channel] {
        store.channels
            .filter { store.isFavorite($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favoriteChannels.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "star",
                        description: Text("Tap the star on any channel to add it here.")
                    )
                } else {
                    List(favoriteChannels) { channel in
                        NavigationLink(value: channel) {
                            ChannelRow(channel: channel)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Channel.self) { channel in
                PlayerView(channel: channel)
            }
        }
    }
}
