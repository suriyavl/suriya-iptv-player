import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject private var store: PlaylistStore
    let channel: Channel
    @State private var player: AVPlayer?
    @State private var showGuide = false

    var body: some View {
        VStack(spacing: 0) {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }

            if let program = store.currentProgram(for: channel) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.headline)
                    if let subtitle = program.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGuide = true
                } label: {
                    Image(systemName: "calendar")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(channel)
                } label: {
                    Image(systemName: store.isFavorite(channel) ? "star.fill" : "star")
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            ChannelGuideView(channel: channel)
        }
        .onAppear {
            player = AVPlayer(url: channel.streamURL)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
