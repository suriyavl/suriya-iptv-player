import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var playlistURL: String = ""
    @State private var epgURL: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "tv.badge.wifi")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Add your IPTV playlist")
                            .font(.title2.bold())
                        Text("Paste an M3U or M3U8 playlist URL to load your channels.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Playlist") {
                    TextField("https://example.com/playlist.m3u8", text: $playlistURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section("EPG (optional)") {
                    TextField("https://example.com/guide.xml", text: $epgURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("XMLTV formatted program guide, matched to channels by tvg-id.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = store.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await store.loadPlaylist(from: playlistURL, epgURLString: epgURL) }
                    } label: {
                        HStack {
                            Spacer()
                            if store.isLoading {
                                ProgressView()
                            } else {
                                Text("Load Channels")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(playlistURL.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
                }
            }
            .navigationTitle("Setup")
            .onAppear {
                playlistURL = store.playlistURLString
                epgURL = store.epgURLString
            }
        }
    }
}

#Preview {
    OnboardingView().environmentObject(PlaylistStore())
}
