import Foundation

enum M3UParser {
    static func parse(_ contents: String) -> [Channel] {
        var channels: [Channel] = []
        var pendingAttributes: [String: String] = [:]
        var pendingName: String?

        contents.enumerateLines { rawLine, _ in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return }

            if line.hasPrefix("#EXTINF") {
                guard let commaRange = line.range(of: ",", options: .backwards) else { return }
                let attributesPart = line[line.index(line.startIndex, offsetBy: "#EXTINF:".count)..<commaRange.lowerBound]
                let namePart = String(line[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                pendingAttributes = parseAttributes(String(attributesPart))
                pendingName = namePart.isEmpty ? "Unnamed Channel" : namePart
            } else if line.hasPrefix("#") {
                return
            } else {
                guard let name = pendingName, let url = URL(string: line) else {
                    pendingName = nil
                    pendingAttributes = [:]
                    return
                }
                let tvgID = pendingAttributes["tvg-id"]
                let logo = pendingAttributes["tvg-logo"].flatMap(URL.init(string:))
                let group = pendingAttributes["group-title"]?.isEmpty == false ? pendingAttributes["group-title"]! : Channel.uncategorized
                let idBase = tvgID?.isEmpty == false ? tvgID! : line
                let channel = Channel(
                    id: idBase,
                    name: name,
                    streamURL: url,
                    logoURL: logo,
                    group: group,
                    tvgID: tvgID
                )
                channels.append(channel)
                pendingName = nil
                pendingAttributes = [:]
            }
        }
        return channels
    }

    private static func parseAttributes(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        var index = text.startIndex
        while index < text.endIndex {
            guard let equalsIndex = text[index...].firstIndex(of: "=") else { break }
            let key = text[index..<equalsIndex].trimmingCharacters(in: .whitespaces)
            var cursor = text.index(after: equalsIndex)
            guard cursor < text.endIndex, text[cursor] == "\"" else { break }
            cursor = text.index(after: cursor)
            guard let closingQuote = text[cursor...].firstIndex(of: "\"") else { break }
            let value = String(text[cursor..<closingQuote])
            if !key.isEmpty {
                result[key] = value
            }
            index = text.index(after: closingQuote)
        }
        return result
    }
}
