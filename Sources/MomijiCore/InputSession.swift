public final class InputSession {
    private struct Conversion {
        var candidates: [ConversionCandidate]
        var selected = 0
        var windowVisible = false
        var override: String?
        var segmentLength: Int
        var restText = ""
    }

    private let backend: any ConversionBackend
    public var options: SessionOptions
    public private(set) var state = SessionState()
    private var conversion: Conversion?
    private var suggestions: [String] = []

    public static let pageSize = 10

    public init(backend: any ConversionBackend, options: SessionOptions) {
        self.backend = backend
        self.options = options
    }

    public func handle(_ input: KeyInput) -> HandleResult {
        let result = conversion == nil ? handleComposing(input) : handleConverting(input)
        updateSuggestions()
        refreshState()
        return result
    }

    public func commitAll() -> String? {
        let text: String? = if conversion != nil {
            commitConversion()
        } else if backend.reading.isEmpty {
            nil
        } else {
            commitComposition()
        }
        refreshState()
        return text
    }

    private func insertableCharacter(_ input: KeyInput) -> Character? {
        guard case .character(let character) = input.key, input.modifiers.isSubset(of: .shift) else {
            return nil
        }
        return character
    }

    private func handleComposing(_ input: KeyInput) -> HandleResult {
        if let character = insertableCharacter(input) {
            backend.insert(String(character))
            return .consumed
        }
        guard !backend.reading.isEmpty else {
            return .ignored
        }
        if input.key == .down, input.modifiers.isEmpty, !suggestions.isEmpty {
            startPrediction()
            return .consumed
        }
        guard let action = Keymap.action(for: input, mode: .composition) else {
            return input.modifiers.contains(.command) ? .ignored : .consumed
        }
        switch action {
        case .convert:
            startConversion()
        case .predict:
            startPrediction()
        case .commit:
            return HandleResult(handled: true, commitText: commitComposition())
        case .cancel:
            backend.reset()
        case .backspace:
            backend.deleteBackward()
        case .delete:
            backend.deleteForward()
        case .cursorLeft:
            backend.moveCursor(by: -1)
        case .cursorRight:
            backend.moveCursor(by: 1)
        case .cursorStart:
            backend.moveCursorToStart()
        case .cursorEnd:
            backend.moveCursorToEnd()
        case .insertFullSpace:
            backend.insert("　")
        case .display(let form):
            backend.prepareForConversion()
            backend.moveCursorToEnd()
            startConversion()
            applyDisplay(form)
        default:
            break
        }
        return .consumed
    }

    private func handleConverting(_ input: KeyInput) -> HandleResult {
        if let current = conversion, current.windowVisible, input.modifiers.isEmpty,
           case .character(let character) = input.key,
           let index = SelectionKeys.index(of: character, layout: options.selectionKeyLayout) {
            return selectOnPage(index, in: current)
        }
        if let character = insertableCharacter(input) {
            let committed = commitConversion()
            backend.insert(String(character))
            return HandleResult(handled: true, commitText: committed)
        }
        guard let action = Keymap.action(for: input, mode: .conversion) else {
            return input.modifiers.contains(.command) ? .ignored : .consumed
        }
        switch action {
        case .commit:
            return HandleResult(handled: true, commitText: commitConversion())
        case .cancel:
            conversion = nil
            backend.moveCursorToEnd()
        case .nextCandidate:
            if conversion?.windowVisible == true {
                moveSelection(by: 1)
            } else {
                conversion?.windowVisible = true
                moveSelection(by: 1)
            }
        case .prevCandidate:
            moveSelection(by: -1)
        case .nextPage:
            movePage(by: 1)
        case .prevPage:
            movePage(by: -1)
        case .segmentShrink, .segmentFocusLeft:
            resizeSegment(by: -1)
        case .segmentExpand, .segmentFocusRight:
            resizeSegment(by: 1)
        case .display(let form):
            applyDisplay(form)
        default:
            break
        }
        return .consumed
    }

    private func startConversion() {
        backend.prepareForConversion()
        backend.moveCursorToEnd()
        conversion = Conversion(candidates: segmentCandidates(), segmentLength: backend.cursor)
    }

    private func startPrediction() {
        let predictions = backend.predictions(useZenzai: true)
        guard !predictions.isEmpty else { return }
        backend.moveCursorToEnd()
        conversion = Conversion(candidates: predictions, windowVisible: true, segmentLength: backend.reading.count)
    }

    private func updateSuggestions() {
        guard options.suggestionEnabled, conversion == nil, !backend.reading.isEmpty else {
            suggestions = []
            return
        }
        suggestions = backend.predictions(useZenzai: false).prefix(5).map(\.text)
    }

    private func segmentCandidates() -> [ConversionCandidate] {
        let all = backend.candidates()
        let exact = all.filter { $0.readingCount == backend.cursor }
        return exact.isEmpty ? all : exact
    }

    private func resizeSegment(by offset: Int) {
        guard var current = conversion else { return }
        let length = current.segmentLength + offset
        guard length >= 1, length <= backend.reading.count else { return }
        backend.moveCursorToStart()
        backend.moveCursor(by: length)
        current.segmentLength = length
        current.candidates = segmentCandidates()
        current.restText = backend.bestConversion(ofReadingFrom: length)
        backend.moveCursorToStart()
        backend.moveCursor(by: length)
        current.selected = 0
        current.override = nil
        conversion = current
    }

    private func moveSelection(by offset: Int) {
        guard var current = conversion, !current.candidates.isEmpty else { return }
        current.override = nil
        current.selected = (current.selected + offset + current.candidates.count) % current.candidates.count
        conversion = current
    }

    private func selectOnPage(_ index: Int, in current: Conversion) -> HandleResult {
        let target = current.selected / Self.pageSize * Self.pageSize + index
        guard current.candidates.indices.contains(target) else {
            return .consumed
        }
        conversion?.selected = target
        conversion?.override = nil
        return HandleResult(handled: true, commitText: commitConversion())
    }

    private func movePage(by offset: Int) {
        guard var current = conversion, !current.candidates.isEmpty else { return }
        let pageCount = (current.candidates.count + Self.pageSize - 1) / Self.pageSize
        let page = (current.selected / Self.pageSize + offset + pageCount) % pageCount
        current.selected = page * Self.pageSize
        current.windowVisible = true
        current.override = nil
        conversion = current
    }

    private func applyDisplay(_ form: CharacterForm) {
        guard var current = conversion else { return }
        let segment = String(backend.reading.prefix(current.segmentLength))
        let roman = current.segmentLength == backend.reading.count ? backend.romanInput : segment
        current.override = CharacterFormConverter.convert(reading: segment, romanInput: roman, to: form)
        current.windowVisible = false
        conversion = current
    }

    private func commitComposition() -> String {
        backend.prepareForConversion()
        let text = backend.reading
        backend.reset()
        return text
    }

    private func commitConversion() -> String {
        guard let current = conversion else { return "" }
        conversion = nil
        var text = ""
        if let override = current.override {
            text += override
            dropPrefix(current.segmentLength)
        } else if current.candidates.indices.contains(current.selected) {
            let candidate = current.candidates[current.selected]
            text += candidate.text
            backend.commit(candidate)
        }
        text += current.restText
        backend.reset()
        return text
    }

    private func dropPrefix(_ count: Int) {
        backend.moveCursorToStart()
        backend.moveCursor(by: count)
        for _ in 0..<count {
            backend.deleteBackward()
        }
    }

    private func refreshState() {
        var next = SessionState()
        if let current = conversion {
            let focused = current.override ?? (current.candidates.indices.contains(current.selected) ? current.candidates[current.selected].text : "")
            next.marked = [MarkedSegment(text: focused, isFocused: true)]
            if !current.restText.isEmpty {
                next.marked.append(MarkedSegment(text: current.restText, isFocused: false))
            }
            if current.windowVisible {
                next.candidateWindow = windowModel(current)
            }
        } else if !backend.reading.isEmpty {
            next.marked = [MarkedSegment(text: backend.reading, isFocused: false)]
            next.cursor = backend.cursor
            next.suggestions = suggestions
        }
        state = next
    }

    private func windowModel(_ current: Conversion) -> CandidateWindowModel {
        let pageIndex = current.selected / Self.pageSize
        let start = pageIndex * Self.pageSize
        let texts = current.candidates[start..<min(start + Self.pageSize, current.candidates.count)].map(\.text)
        return CandidateWindowModel(
            candidates: texts,
            labels: Array(SelectionKeys.labels(for: options.selectionKeyLayout).prefix(texts.count)),
            selectedIndex: current.selected - start,
            page: pageIndex + 1,
            pageCount: (current.candidates.count + Self.pageSize - 1) / Self.pageSize
        )
    }
}
