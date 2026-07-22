import Foundation
import Combine

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var programsByChannel: [String: [EPGProgram]] = [:]
    @Published var favoriteIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published var playlistURLString: String = ""
    @Published var epgURLString: String = ""

    var categories: [String] {
        let groups = Set(channels.map(\.group))
        return groups.sorted { lhs, rhs in
            if lhs == Channel.uncategorized { return false }
            if rhs == Channel.uncategorized { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    var hasContent: Bool { !channels.isEmpty }

    private let defaults = UserDefaults.standard
    private let channelsKey = "iptv.channels"
    private let favoritesKey = "iptv.favorites"
    private let playlistURLKey = "iptv.playlistURL"
    private let epgURLKey = "iptv.epgURL"

    init() {
        loadPersistedState()
    }

    func currentProgram(for channel: Channel) -> EPGProgram? {
        guard let tvgID = channel.tvgID, let programs = programsByChannel[tvgID] else { return nil }
        let now = Date()
        return programs.first { $0.isLive(at: now) }
    }

    func upcomingPrograms(for channel: Channel, limit: Int = 5) -> [EPGProgram] {
        guard let tvgID = channel.tvgID, let programs = programsByChannel[tvgID] else { return [] }
        let now = Date()
        return programs.filter { $0.stop > now }.sorted { $0.start < $1.start }.prefix(limit).map { $0 }
    }

    func isFavorite(_ channel: Channel) -> Bool {
        favoriteIDs.contains(channel.id)
    }

    func toggleFavorite(_ channel: Channel) {
        if favoriteIDs.contains(channel.id) {
            favoriteIDs.remove(channel.id)
        } else {
            favoriteIDs.insert(channel.id)
        }
        persistFavorites()
    }

    func loadPlaylist(from urlString: String, epgURLString: String) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastError = "That doesn't look like a valid URL."
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                lastError = "Couldn't read the playlist as text."
                return
            }
            let parsed = M3UParser.parse(text)
            guard !parsed.isEmpty else {
                lastError = "No channels found in that playlist."
                return
            }
            channels = parsed
            self.playlistURLString = urlString
            self.epgURLString = epgURLString
            persistChannels()
            defaults.set(urlString, forKey: playlistURLKey)
            defaults.set(epgURLString, forKey: epgURLKey)

            if let epgURL = URL(string: epgURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
               !epgURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await loadEPG(from: epgURL)
            }
        } catch {
            lastError = "Failed to load playlist: \(error.localizedDescription)"
        }
    }

    private func loadEPG(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let programs = XMLTVParser.parse(data: data)
            var grouped: [String: [EPGProgram]] = [:]
            for program in programs {
                grouped[program.channelID, default: []].append(program)
            }
            programsByChannel = grouped
        } catch {
            lastError = "Loaded channels, but EPG failed: \(error.localizedDescription)"
        }
    }

    func reload() async {
        await loadPlaylist(from: playlistURLString, epgURLString: epgURLString)
    }

    private func persistChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            defaults.set(data, forKey: channelsKey)
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favoriteIDs), forKey: favoritesKey)
    }

    private func loadPersistedState() {
        if let data = defaults.data(forKey: channelsKey),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            channels = decoded
        }
        if let favorites = defaults.array(forKey: favoritesKey) as? [String] {
            favoriteIDs = Set(favorites)
        }
        playlistURLString = defaults.string(forKey: playlistURLKey) ?? ""
        epgURLString = defaults.string(forKey: epgURLKey) ?? ""
    }
}
