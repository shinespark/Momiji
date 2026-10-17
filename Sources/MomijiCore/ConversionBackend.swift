public struct ConversionCandidate: Equatable, Sendable {
    public let text: String
    public let readingCount: Int
    public let id: Int

    public init(text: String, readingCount: Int, id: Int) {
        self.text = text
        self.readingCount = readingCount
        self.id = id
    }
}

public protocol ConversionBackend: AnyObject {
    var reading: String { get }
    var romanInput: String { get }
    var cursor: Int { get }
    func insert(_ text: String)
    func deleteBackward()
    func deleteForward()
    func moveCursor(by offset: Int)
    func moveCursorToStart()
    func moveCursorToEnd()
    func reset()
    func candidates() -> [ConversionCandidate]
    func predictions(useZenzai: Bool) -> [ConversionCandidate]
    func commit(_ candidate: ConversionCandidate)
    func prepareForConversion()
    func readingForConversion() -> String
}
