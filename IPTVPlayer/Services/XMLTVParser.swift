import Foundation

final class XMLTVParser: NSObject, XMLParserDelegate {
    private var programs: [EPGProgram] = []

    private var currentElement = ""
    private var currentChannelID: String?
    private var currentStart: Date?
    private var currentStop: Date?
    private var currentTitle = ""
    private var currentSubtitle = ""
    private var isInProgramme = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func parse(data: Data) -> [EPGProgram] {
        let parser = XMLTVParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.programs
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        guard elementName == "programme" else { return }
        isInProgramme = true
        currentChannelID = attributeDict["channel"]
        currentStart = attributeDict["start"].flatMap { Self.dateFormatter.date(from: normalizeTimestamp($0)) }
        currentStop = attributeDict["stop"].flatMap { Self.dateFormatter.date(from: normalizeTimestamp($0)) }
        currentTitle = ""
        currentSubtitle = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInProgramme else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "sub-title":
            currentSubtitle += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "programme" else { return }
        isInProgramme = false
        if let channelID = currentChannelID, let start = currentStart, let stop = currentStop, !currentTitle.isEmpty {
            let program = EPGProgram(
                channelID: channelID,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: currentSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : currentSubtitle,
                start: start,
                stop: stop
            )
            programs.append(program)
        }
        currentChannelID = nil
        currentStart = nil
        currentStop = nil
    }

    private func normalizeTimestamp(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(" ") {
            return trimmed
        }
        return trimmed + " +0000"
    }
}
