import Foundation

struct SubtitleCue {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum SubtitleParser {
    static func parseSRT(_ content: String) -> [SubtitleCue] {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n\n")
            .compactMap(parseBlock)
    }

    private static func parseBlock(_ block: String) -> SubtitleCue? {
        let lines = block
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
            return nil
        }

        let timingParts = lines[timingIndex].components(separatedBy: "-->")
        guard timingParts.count == 2,
              let start = parseTimestamp(timingParts[0]),
              let end = parseTimestamp(timingParts[1]) else {
            return nil
        }

        let text = lines
            .dropFirst(timingIndex + 1)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        return SubtitleCue(start: start, end: end, text: stripTags(text))
    }

    private static func parseTimestamp(_ value: String) -> TimeInterval? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: ":,"))
        guard parts.count == 4,
              let hours = TimeInterval(parts[0]),
              let minutes = TimeInterval(parts[1]),
              let seconds = TimeInterval(parts[2]),
              let milliseconds = TimeInterval(parts[3]) else {
            return nil
        }

        return (hours * 3600) + (minutes * 60) + seconds + (milliseconds / 1000)
    }

    private static func stripTags(_ value: String) -> String {
        value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
