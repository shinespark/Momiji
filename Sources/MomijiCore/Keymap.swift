public enum CharacterForm: Equatable, Sendable {
    case hiragana, fullKatakana, halfWidth, fullAlphanumeric, halfAlphanumeric
}

public enum KeyAction: Equatable, Sendable {
    case convert, nextCandidate, prevCandidate, nextPage, prevPage, commit, cancel
    case backspace, delete, cursorLeft, cursorRight, cursorStart, cursorEnd
    case segmentShrink, segmentExpand, segmentFocusLeft, segmentFocusRight
    case predict, display(CharacterForm), insertFullSpace
}

public enum KeymapMode: Sendable {
    case composition, conversion
}

public enum Keymap {
    private struct Binding: Hashable {
        let key: KeyInput.Key
        let modifiers: KeyInput.Modifiers
    }

    private static func bindings(_ entries: [(KeyInput.Key, KeyInput.Modifiers, KeyAction)]) -> [Binding: KeyAction] {
        Dictionary(uniqueKeysWithValues: entries.map { (Binding(key: $0.0, modifiers: $0.1), $0.2) })
    }

    private static let characterForms: [(KeyInput.Key, KeyInput.Modifiers, KeyAction)] = [
        (.character(";"), .control, .display(.halfWidth)),
        (.character(":"), .control, .display(.halfAlphanumeric)),
        (.character(":"), [.control, .shift], .display(.halfAlphanumeric)),
        (.character("'"), .control, .display(.halfAlphanumeric)),
        (.character("j"), .control, .display(.hiragana)),
        (.character("k"), .control, .display(.fullKatakana)),
        (.character("l"), .control, .display(.fullAlphanumeric)),
        (.function(6), [], .display(.hiragana)),
        (.function(7), [], .display(.fullKatakana)),
        (.function(8), [], .display(.halfWidth)),
        (.function(9), [], .display(.fullAlphanumeric)),
        (.function(10), [], .display(.halfAlphanumeric)),
        (.function(1), .option, .display(.hiragana)),
        (.function(2), .option, .display(.fullKatakana)),
        (.function(3), .option, .display(.fullAlphanumeric)),
        (.function(4), .option, .display(.halfWidth)),
        (.function(5), .option, .display(.halfAlphanumeric)),
        (.character("a"), .option, .display(.halfWidth)),
        (.character("c"), .option, .display(.fullAlphanumeric)),
        (.character("s"), .option, .display(.halfAlphanumeric)),
        (.character("x"), .option, .display(.fullKatakana)),
        (.character("z"), .option, .display(.hiragana)),
        (.enter, [], .commit),
        (.character("m"), .control, .commit),
        (.escape, [], .cancel),
        (.tab, [], .predict),
    ]

    private static let composition = bindings(characterForms + [
        (.backspace, [], .backspace),
        (.character("h"), .control, .backspace),
        (.delete, [], .delete),
        (.character("d"), .control, .delete),
        (.character("g"), .control, .cancel),
        (.left, [], .cursorLeft),
        (.character("b"), .control, .cursorLeft),
        (.character("j"), .option, .cursorLeft),
        (.right, [], .cursorRight),
        (.character("f"), .control, .cursorRight),
        (.character("l"), .option, .cursorRight),
        (.home, [], .cursorStart),
        (.character("a"), .control, .cursorStart),
        (.left, .control, .cursorStart),
        (.end, [], .cursorEnd),
        (.character("e"), .control, .cursorEnd),
        (.right, .control, .cursorEnd),
        (.space, [], .convert),
        (.space, .option, .insertFullSpace),
    ])

    private static let conversion = bindings(characterForms + [
        (.backspace, [], .cancel),
        (.character("h"), .control, .cancel),
        (.space, [], .nextCandidate),
        (.down, [], .nextCandidate),
        (.character("n"), .control, .nextCandidate),
        (.character("x"), .control, .nextCandidate),
        (.character("k"), .option, .nextCandidate),
        (.space, .shift, .prevCandidate),
        (.tab, .shift, .prevCandidate),
        (.up, [], .prevCandidate),
        (.character("p"), .control, .prevCandidate),
        (.character("e"), .control, .prevCandidate),
        (.character("i"), .option, .prevCandidate),
        (.pageDown, [], .nextPage),
        (.down, .shift, .nextPage),
        (.pageUp, [], .prevPage),
        (.up, .shift, .prevPage),
        (.left, .shift, .segmentShrink),
        (.character("i"), .control, .segmentShrink),
        (.character("q"), .control, .segmentShrink),
        (.right, .shift, .segmentExpand),
        (.character("o"), .control, .segmentExpand),
        (.character("w"), .control, .segmentExpand),
        (.left, [], .segmentFocusLeft),
        (.character("b"), .control, .segmentFocusLeft),
        (.character("s"), .control, .segmentFocusLeft),
        (.right, [], .segmentFocusRight),
        (.character("f"), .control, .segmentFocusRight),
        (.character("d"), .control, .segmentFocusRight),
    ])

    public static func action(for input: KeyInput, mode: KeymapMode) -> KeyAction? {
        let binding = Binding(key: input.key, modifiers: input.modifiers)
        switch mode {
        case .composition: return composition[binding]
        case .conversion: return conversion[binding]
        }
    }
}
