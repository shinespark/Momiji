import Testing
@testable import MomijiCore

func makeSession(_ dictionary: [String: [String]] = [:], layout: SelectionKeyLayout = .dvorak) -> (InputSession, FakeBackend) {
    let backend = FakeBackend(dictionary: dictionary)
    let session = InputSession(backend: backend, options: .init(selectionKeyLayout: layout, suggestionEnabled: false))
    return (session, backend)
}

@discardableResult
func type(_ text: String, into session: InputSession) -> [HandleResult] {
    text.map { session.handle(.init(key: .character($0))) }
}

@discardableResult
func press(_ key: KeyInput.Key, _ modifiers: KeyInput.Modifiers = [], into session: InputSession) -> HandleResult {
    session.handle(.init(key: key, modifiers: modifiers))
}

let kanjiDictionary = [
    "かんじ": ["漢字", "感じ", "幹事"],
    "かんじへんかん": ["漢字変換"],
    "かんじへんか": ["漢字変化"],
    "かんじへん": ["漢字編"],
    "かんじへ": ["漢字へ"],
    "へんかん": ["変換", "返還"],
]

@Test func spaceConvertsWithoutWindow() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじ", into: session)
    press(.space, into: session)
    #expect(session.state.marked == [MarkedSegment(text: "漢字", isFocused: true)])
    #expect(session.state.candidateWindow == nil)
}

@Test func secondSpaceOpensWindow() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじ", into: session)
    press(.space, into: session)
    press(.space, into: session)
    #expect(session.state.candidateWindow?.selectedIndex == 1)
    #expect(session.state.candidateWindow?.page == 1)
}

@Test func enterCommitsAll() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじへんかん", into: session)
    press(.space, into: session)
    for _ in 0..<4 { press(.left, .shift, into: session) }
    let result = press(.enter, into: session)
    #expect(result.commitText == "漢字変換")
    #expect(session.state.marked.isEmpty)
}

@Test func shiftLeftShrinksSegment() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじへんかん", into: session)
    press(.space, into: session)
    press(.left, .shift, into: session)
    #expect(session.state.marked == [MarkedSegment(text: "漢字変化", isFocused: true), MarkedSegment(text: "ん", isFocused: false)])
}

@Test func optionXMakesKatakana() {
    let (session, _) = makeSession()
    type("かな", into: session)
    press(.character("x"), .option, into: session)
    #expect(session.state.marked == [MarkedSegment(text: "カナ", isFocused: true)])
    #expect(press(.enter, into: session).commitText == "カナ")
}

@Test func escapeReturnsToComposition() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじ", into: session)
    press(.space, into: session)
    press(.escape, into: session)
    #expect(session.state.marked == [MarkedSegment(text: "かんじ", isFocused: false)])
    #expect(session.state.candidateWindow == nil)
}

@Test func typingDuringConversionCommits() {
    let (session, _) = makeSession(kanjiDictionary)
    type("かんじ", into: session)
    press(.space, into: session)
    let result = type("a", into: session)
    #expect(result.last?.commitText == "漢字")
    #expect(session.state.marked == [MarkedSegment(text: "a", isFocused: false)])
}

@Test func halfAlphanumericUsesRoman() {
    let (session, _) = makeSession()
    type("kanji", into: session)
    press(.function(10), into: session)
    #expect(session.state.marked.first?.text == "kanji")
}

@Test func emptySessionPassesKeysThrough() {
    let (session, _) = makeSession()
    #expect(press(.space, into: session).handled == false)
    #expect(press(.enter, into: session).handled == false)
}

let koukaDictionary = ["こうか": ["効果", "硬貨", "高価"]]
let manyDictionary = ["こうか": (0..<25).map { "候補\($0)" }]

func openWindow(_ dictionary: [String: [String]], layout: SelectionKeyLayout = .dvorak) -> InputSession {
    let (session, _) = makeSession(dictionary, layout: layout)
    type("こうか", into: session)
    press(.space, into: session)
    press(.space, into: session)
    return session
}

@Test func dvorakHomeKeyCommits() {
    let session = openWindow(koukaDictionary)
    #expect(type("e", into: session).last?.commitText == "高価")
    #expect(session.state.marked.isEmpty)
}

@Test func digitCommits() {
    let session = openWindow(koukaDictionary)
    #expect(type("3", into: session).last?.commitText == "高価")
}

@Test func qwertyLayout() {
    let session = openWindow(koukaDictionary, layout: .qwerty)
    #expect(session.state.candidateWindow?.labels == ["a", "s", "d"])
    #expect(type("d", into: session).last?.commitText == "高価")
}

@Test func secondPageSelection() {
    let session = openWindow(manyDictionary)
    press(.pageDown, into: session)
    #expect(session.state.candidateWindow?.page == 2)
    #expect(type("a", into: session).last?.commitText == "候補10")
}

@Test func outOfRangeKeyIgnored() {
    let session = openWindow(koukaDictionary)
    let result = type("s", into: session).last
    #expect(result == HandleResult(handled: true, commitText: nil))
    #expect(session.state.candidateWindow != nil)
}

@Test func otherLetterCommitsThenTypes() {
    let session = openWindow(koukaDictionary)
    #expect(type("f", into: session).last?.commitText == "硬貨")
    #expect(session.state.marked == [MarkedSegment(text: "f", isFocused: false)])
}

@Test func pageIndicator() {
    let session = openWindow(manyDictionary)
    #expect(session.state.candidateWindow?.pageCount == 3)
}

@Test func spaceMovesAcrossPages() {
    let session = openWindow(manyDictionary)
    for _ in 0..<9 { press(.space, into: session) }
    #expect(session.state.candidateWindow?.page == 2)
    #expect(session.state.candidateWindow?.selectedIndex == 0)
}

@Test func homeKeysTypeWhenNoWindow() {
    let (session, _) = makeSession(koukaDictionary)
    type("こうか", into: session)
    press(.space, into: session)
    #expect(type("a", into: session).last?.commitText == "効果")
    #expect(session.state.marked == [MarkedSegment(text: "a", isFocused: false)])
}

@Test func layoutChangeAppliesImmediately() {
    let session = openWindow(koukaDictionary)
    session.options.selectionKeyLayout = .qwerty
    #expect(type("d", into: session).last?.commitText == "高価")
}

func suggestingSession(enabled: Bool = true) -> InputSession {
    let backend = FakeBackend()
    backend.predictionTexts = ["ありがとう", "ありがとうございます"]
    let session = InputSession(backend: backend, options: .init(selectionKeyLayout: .dvorak, suggestionEnabled: enabled))
    type("ありが", into: session)
    return session
}

@Test func suggestionsWhileTyping() {
    #expect(suggestingSession().state.suggestions == ["ありがとう", "ありがとうございます"])
}

@Test func suggestionsDisabled() {
    #expect(suggestingSession(enabled: false).state.suggestions.isEmpty)
}

@Test func tabOpensPredictionWindow() {
    let session = suggestingSession(enabled: false)
    press(.tab, into: session)
    #expect(session.state.candidateWindow?.candidates == ["ありがとう", "ありがとうございます"])
    #expect(session.state.suggestions.isEmpty)
}

@Test func downFromSuggestionOpensWindow() {
    let session = suggestingSession()
    press(.down, into: session)
    #expect(session.state.candidateWindow?.candidates == ["ありがとう", "ありがとうございます"])
}

@Test func homeKeyCommitsPrediction() {
    let session = suggestingSession()
    press(.tab, into: session)
    #expect(type("o", into: session).last?.commitText == "ありがとうございます")
    #expect(session.state.marked.isEmpty)
}

@Test func homeKeyTypesDuringSuggestion() {
    let session = suggestingSession()
    let result = type("a", into: session).last
    #expect(result?.commitText == nil)
    #expect(session.state.marked == [MarkedSegment(text: "ありがa", isFocused: false)])
}

@Test func downWithoutSuggestionDoesNothing() {
    let (session, _) = makeSession()
    type("ありが", into: session)
    press(.down, into: session)
    #expect(session.state.candidateWindow == nil)
}
