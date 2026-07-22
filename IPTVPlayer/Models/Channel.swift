import Foundation

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var streamURL: URL
    var logoURL: URL?
    var group: String
    var tvgID: String?

    init(id: String = UUID().uuidString, name: String, streamURL: URL, logoURL: URL? = nil, group: String, tvgID: String? = nil) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.group = group
        self.tvgID = tvgID
    }
}

extension Channel {
    static let uncategorized = "Uncategorized"
}
