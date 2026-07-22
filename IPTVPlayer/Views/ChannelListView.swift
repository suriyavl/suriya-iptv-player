import SwiftUI

struct ChannelListView: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var filteredChannels: [Channel] {
        store.channels.filter { channel in
            let matchesCategory = selectedCategory == nil || channel.group == selectedCategory
            let matchesSearch = searchText.isEmpty || channel.name.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var groupedChannels: [(category: String, channels: [Channel])] {
        let groups = Dictionary(grouping: filteredChannels, by: \.group)
        return groups.keys.sorted { lhs, rhs in
            if lhs == Channel.uncategorized { return false }
            if rhs == Channel.uncategorized { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { ($0, groups[$0]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !store.hasContent {
                    ContentUnavailableView(
                        "No Channels",
                        systemImage: "tv.slash",
                        description: Text("Load a playlist from Settings to get started.")
                    )
                } else {
                    List {
                        if !store.categories.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                                            selectedCategory = nil
                                        }
                                        ForEach(store.categories, id: \.self) { category in
                                            CategoryChip(title: category, isSelected: selectedCategory == category) {
                                                selectedCategory = category
                                            }
                                        }
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }

                        ForEach(groupedChannels, id: \.category) { group in
                            Section(group.category) {
                                ForEach(group.channels) { channel in
                                    NavigationLink(value: channel) {
                                        ChannelRow(channel: channel)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Channels")
            .searchable(text: $searchText, prompt: "Search channels")
            .navigationDestination(for: Channel.self) { channel in
                PlayerView(channel: channel)
            }
            .refreshable {
                await store.reload()
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
