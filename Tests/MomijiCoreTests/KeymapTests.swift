import Testing
@testable import MomijiCore

@Test func optionXIsKatakanaInComposition() throws {
    let input = try #require(KeyInput.make(keyCode: 7, charactersIgnoringModifiers: "x", modifiers: .option))
    #expect(Keymap.action(for: input, mode: .composition) == .display(.fullKatakana))
}

@Test func optionXIsKatakanaInConversion() {
    #expect(Keymap.action(for: .init(key: .character("x"), modifiers: .option), mode: .conversion) == .display(.fullKatakana))
}

@Test func shiftArrowsResizeSegment() {
    #expect(Keymap.action(for: .init(key: .left, modifiers: .shift), mode: .conversion) == .segmentShrink)
    #expect(Keymap.action(for: .init(key: .right, modifiers: .shift), mode: .conversion) == .segmentExpand)
}

@Test func spaceAndTab() {
    #expect(Keymap.action(for: .init(key: .space), mode: .composition) == .convert)
    #expect(Keymap.action(for: .init(key: .space), mode: .conversion) == .nextCandidate)
    #expect(Keymap.action(for: .init(key: .tab), mode: .composition) == .predict)
}

@Test func ctrlKAndF7() {
    #expect(Keymap.action(for: .init(key: .character("k"), modifiers: .control), mode: .composition) == .display(.fullKatakana))
    #expect(Keymap.action(for: .init(key: .function(7)), mode: .conversion) == .display(.fullKatakana))
}

@Test func plainLetterHasNoAction() {
    #expect(Keymap.action(for: .init(key: .character("a")), mode: .composition) == nil)
}

@Test func makeSpecialKeys() {
    #expect(KeyInput.make(keyCode: 49, charactersIgnoringModifiers: " ", modifiers: [])?.key == .space)
}

@Test func ctrlColonWithShift() {
    #expect(Keymap.action(for: .init(key: .character(":"), modifiers: [.control, .shift]), mode: .composition) == .display(.halfAlphanumeric))
}
