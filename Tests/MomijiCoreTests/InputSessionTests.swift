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
