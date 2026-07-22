import SwiftUI

struct ChannelGuideView: View {
    @EnvironmentObject private var store: PlaylistStore
    let channel: Channel
    @Environment(\.dismiss) private var dismiss

    private var upcoming: [EPGProgram] {
        store.upcomingPrograms(for: channel, limit: 20)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if upcoming.isEmpty {
                    ContentUnavailableView(
                        "No Guide Data",
                        systemImage: "calendar",
                        description: Text("Add an EPG URL in Settings to see the program guide.")
                    )
                } else {
                    List(upcoming) { program in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(program.title).font(.body)
                                if let subtitle = program.subtitle {
                                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(Self.timeFormatter.string(from: program.start))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(program.isLive() ? Color.accentColor.opacity(0.15) : nil)
                    }
                }
            }
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
