import Foundation

struct EPGProgram: Identifiable, Codable, Hashable {
    var id: String { "\(channelID)-\(start.timeIntervalSince1970)" }
    let channelID: String
    let title: String
    let subtitle: String?
    let start: Date
    let stop: Date

    func isLive(at date: Date = Date()) -> Bool {
        date >= start && date < stop
    }
}
