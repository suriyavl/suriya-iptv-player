import SwiftUI

struct ChannelRow: View {
    @EnvironmentObject private var store: PlaylistStore
    let channel: Channel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.logoURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "tv")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                    .lineLimit(1)
                if let program = store.currentProgram(for: channel) {
                    Text(program.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(channel.group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                store.toggleFavorite(channel)
            } label: {
                Image(systemName: store.isFavorite(channel) ? "star.fill" : "star")
                    .foregroundStyle(store.isFavorite(channel) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
