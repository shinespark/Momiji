@testable import MomijiCore

final class FakeBackend: ConversionBackend {
    var dictionary: [String: [String]] = [:]
    var predictionTexts: [String] = []
    private(set) var reading = ""
    private(set) var romanInput = ""
    private(set) var cursor = 0
    private(set) var committed: [String] = []

    init(dictionary: [String: [String]] = [:]) {
        self.dictionary = dictionary
    }

    func insert(_ text: String) {
        let index = reading.index(reading.startIndex, offsetBy: cursor)
        reading.insert(contentsOf: text, at: index)
        romanInput += text
        cursor += text.count
    }

    func deleteBackward() {
        guard cursor > 0 else { return }
        reading.remove(at: reading.index(reading.startIndex, offsetBy: cursor - 1))
        cursor -= 1
    }

    func deleteForward() {
        guard cursor < reading.count else { return }
        reading.remove(at: reading.index(reading.startIndex, offsetBy: cursor))
    }

    func moveCursor(by offset: Int) { cursor = min(max(cursor + offset, 0), reading.count) }
    func moveCursorToStart() { cursor = 0 }
    func moveCursorToEnd() { cursor = reading.count }

    func reset() {
        reading = ""
        romanInput = ""
        cursor = 0
    }

    func candidates() -> [ConversionCandidate] {
        let prefix = String(reading.prefix(cursor))
        let texts = dictionary[prefix] ?? [prefix]
        return texts.enumerated().map { ConversionCandidate(text: $1, readingCount: prefix.count, id: $0) }
    }

    func bestConversion(ofReadingFrom offset: Int) -> String {
        let rest = String(reading.dropFirst(offset))
        return dictionary[rest]?.first ?? rest
    }

    func predictions(useZenzai: Bool) -> [ConversionCandidate] {
        predictionTexts.enumerated().map { ConversionCandidate(text: $1, readingCount: reading.count, id: $0) }
    }

    func commit(_ candidate: ConversionCandidate) {
        committed.append(candidate.text)
        reading = String(reading.dropFirst(candidate.readingCount))
        if reading.isEmpty { romanInput = "" }
        cursor = reading.count
    }

    func prepareForConversion() {}

    func readingForConversion() -> String { reading }
}
