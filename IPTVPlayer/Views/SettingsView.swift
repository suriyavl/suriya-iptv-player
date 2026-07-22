import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var playlistURL: String = ""
    @State private var epgURL: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist") {
                    TextField("Playlist URL", text: $playlistURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("EPG URL (optional)", text: $epgURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        Task { await store.loadPlaylist(from: playlistURL, epgURLString: epgURL) }
                    } label: {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Text("Reload Playlist")
                        }
                    }
                    .disabled(playlistURL.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
                }

                if let error = store.lastError {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section("Library") {
                    LabeledContent("Channels", value: "\(store.channels.count)")
                    LabeledContent("Categories", value: "\(store.categories.count)")
                    LabeledContent("Favorites", value: "\(store.favoriteIDs.count)")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                playlistURL = store.playlistURLString
                epgURL = store.epgURLString
            }
        }
    }
}
