public struct MarkedSegment: Equatable, Sendable {
    public let text: String
    public let isFocused: Bool

    public init(text: String, isFocused: Bool) {
        self.text = text
        self.isFocused = isFocused
    }
}

public struct CandidateWindowModel: Equatable, Sendable {
    public let candidates: [String]
    public let labels: [Character]
    public let selectedIndex: Int
    public let page: Int
    public let pageCount: Int
}

public struct SessionState: Equatable, Sendable {
    public var marked: [MarkedSegment] = []
    public var cursor: Int?
    public var candidateWindow: CandidateWindowModel?
    public var suggestions: [String] = []

    public init() {}
}

public struct SessionOptions: Equatable, Sendable {
    public var selectionKeyLayout: SelectionKeyLayout
    public var suggestionEnabled: Bool

    public init(selectionKeyLayout: SelectionKeyLayout, suggestionEnabled: Bool) {
        self.selectionKeyLayout = selectionKeyLayout
        self.suggestionEnabled = suggestionEnabled
    }
}

public struct HandleResult: Equatable, Sendable {
    public let handled: Bool
    public let commitText: String?

    public init(handled: Bool, commitText: String? = nil) {
        self.handled = handled
        self.commitText = commitText
    }

    static let ignored = HandleResult(handled: false)
    static let consumed = HandleResult(handled: true)
}
